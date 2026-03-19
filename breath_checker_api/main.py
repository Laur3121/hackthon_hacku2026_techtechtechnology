import os
import datetime
import threading
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, db
from sqlalchemy import create_engine, Column, Integer, Float, DateTime, String
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel

app = FastAPI()

# CORS設定：ブラウザからのアクセスを許可
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 1. Cloud SQL 接続設定 ---
DB_USER = "postgres"
DB_PASS = "techtech"
DB_NAME = "postgres"
INSTANCE_CONNECTION_NAME = "project-0e144c7b-cccb-412b-883:asia-northeast1:hachthon-hacku2026"

if os.getenv("K_SERVICE"):
    DATABASE_URL = f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_NAME}?host=/cloudsql/{INSTANCE_CONNECTION_NAME}"
else:
    # ローカル接続用（必要に応じて書き換えてください）
    DB_IP = "104.198.121.0"
    DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASS}@{DB_IP}/{DB_NAME}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# --- モデル定義 ---

class UserGameStatus(Base):
    __tablename__ = "user_game_status"
    user_id = Column(String, primary_key=True, index=True)
    world = Column(Integer, default=1)
    stage = Column(Integer, default=1)
    current_hp = Column(Integer, default=100)
    max_hp = Column(Integer, default=100)
    updated_at = Column(DateTime, default=datetime.datetime.now)

class BattleLog(Base):
    __tablename__ = "battle_log"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String)
    world = Column(Integer)
    stage = Column(Integer)
    damage = Column(Integer)
    diff_percent = Column(Float)
    created_at = Column(DateTime, default=datetime.datetime.now)

class BreathHistory(Base):
    __tablename__ = "breath_history"
    id = Column(Integer, primary_key=True, index=True)
    temperature = Column(Float)
    humidity = Column(Float)
    gas_resistance = Column(Float)
    diff_percent = Column(Float)
    created_at = Column(DateTime, default=datetime.datetime.now)

# テーブル作成（カラム追加後は手動SQLも併用推奨）
Base.metadata.create_all(bind=engine)

# --- 2. Firebase 初期化 ---
cred = credentials.Certificate("hackthon-techtechtechnology-adminsdk.json")
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred, {
        'databaseURL': 'https://hackthon-techtechtechnology-default-rtdb.firebaseio.com/'
    })

# --- 3. ユーティリティ & 型定義 ---

class AttackRequest(BaseModel):
    user_id: str
    damage: int

def get_db():
    db_session = SessionLocal()
    try:
        yield db_session
    finally:
        db_session.close()

# --- 4. エンドポイント ---

# ★Flutter側で「測定」時に使っているエンドポイントを復活
@app.get("/check-firebase")
def check_firebase():
    """センサーの最新値をFirebaseから取得して返す"""
    try:
        sensor_ref = db.reference('/sensor')
        data = sensor_ref.get()
        return {"firebase_data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/game-status/{user_id}")
def get_status(user_id: str, db_session: Session = Depends(get_db)):
    status = db_session.query(UserGameStatus).filter(UserGameStatus.user_id == user_id).first()
    if not status:
        status = UserGameStatus(user_id=user_id)
        db_session.add(status)
        db_session.commit()
        db_session.refresh(status)
    return status

@app.post("/attack")
def attack_enemy(req: AttackRequest, db_session: Session = Depends(get_db)):
    status = db_session.query(UserGameStatus).filter(UserGameStatus.user_id == req.user_id).first()
    if not status:
        status = UserGameStatus(user_id=req.user_id)
        db_session.add(status)

    sensor_data = db.reference('/sensor').get() or {}
    diff_val = sensor_data.get('diff_percent', 0)

    # HP減少
    status.current_hp -= req.damage
    
    # 撃破判定
    if status.current_hp <= 0:
        status.stage += 1
        status.max_hp = 100 + (status.stage - 1) * 50
        status.current_hp = status.max_hp
        if status.stage > 5:
            status.world += 1
            status.stage = 1
    
    status.updated_at = datetime.datetime.now()

    new_log = BattleLog(
        user_id=req.user_id,
        world=status.world,
        stage=status.stage,
        damage=req.damage,
        diff_percent=diff_val
    )
    db_session.add(new_log)
    db_session.commit()

    # Firebase RTDB同期（これがあるからHPバーがヌルヌル動く）
    ref = db.reference(f'users/{req.user_id}/status')
    new_status_dict = {
        "world": status.world,
        "stage": status.stage,
        "current_hp": status.current_hp,
        "max_hp": status.max_hp
    }
    ref.update(new_status_dict)

    return new_status_dict

@app.post("/reset-game")
def reset_game():
    """今回は全ユーザー共通の game_status ではなく個別の初期化が必要なら拡張可能"""
    # 簡易版：とりあえず成功を返す
    return {"message": "Success"}

@app.get("/battle-history/{user_id}")
def get_battle_history(user_id: str, db_session: Session = Depends(get_db)):
    logs = db_session.query(BattleLog)\
        .filter(BattleLog.user_id == user_id)\
        .order_by(BattleLog.created_at.desc())\
        .limit(50).all()
    return logs

# --- 5. 履歴保存スレッド ---
def save_to_postgres(data):
    if not data: return
    try:
        db_session = SessionLocal()
        new_record = BreathHistory(
            temperature=data.get('temperature'),
            humidity=data.get('humidity'),
            gas_resistance=data.get('gas_resistance'),
            diff_percent=data.get('diff_percent')
        )
        db_session.add(new_record)
        db_session.commit()
        db_session.close()
    except Exception as e:
        print(f"Error during SQL sync: {e}")

@app.on_event("startup")
def startup_event():
    # Firebaseの/sensorを監視してDBに生データを溜め続ける
    threading.Thread(target=lambda: db.reference('/sensor').listen(lambda event: save_to_postgres(event.data)), daemon=True).start()