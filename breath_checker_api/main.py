import os
import datetime
import threading
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, db
from sqlalchemy import create_engine, Column, Integer, Float, DateTime, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 1. Cloud SQL 接続情報 ---
DB_USER = "postgres"
DB_PASS = "techtech"
DB_NAME = "postgres"
INSTANCE_CONNECTION_NAME = "project-0e144c7b-cccb-412b-883:asia-northeast1:hachthon-hacku2026"

if os.getenv("K_SERVICE"):
    DATABASE_URL = f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_NAME}?host=/cloudsql/{INSTANCE_CONNECTION_NAME}"
else:
    DB_IP = "104.198.121.0"
    DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASS}@{DB_IP}/{DB_NAME}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# --- 2. テーブル定義 ---

# 測定履歴テーブル
class BreathHistory(Base):
    __tablename__ = "breath_history"
    id = Column(Integer, primary_key=True, index=True)
    temperature = Column(Float)
    humidity = Column(Float)
    gas_resistance = Column(Float)
    diff_percent = Column(Float)
    created_at = Column(DateTime, default=datetime.datetime.now)

# 【追加】ゲーム進行状況テーブル
class GameStatus(Base):
    __tablename__ = "game_status"
    id = Column(Integer, primary_key=True, index=True)
    world = Column(Integer, default=1)
    stage = Column(Integer, default=1)
    current_hp = Column(Integer, default=100)
    max_hp = Column(Integer, default=100)
    updated_at = Column(DateTime, default=datetime.datetime.now, onupdate=datetime.datetime.now)

Base.metadata.create_all(bind=engine)

# 初期データ投入（データが1件もない場合のみ実行）
def init_game_data():
    db_session = SessionLocal()
    if not db_session.query(GameStatus).first():
        first_status = GameStatus(world=1, stage=1, current_hp=100, max_hp=100)
        db_session.add(first_status)
        db_session.commit()
    db_session.close()

init_game_data()

# --- 3. Firebase 初期化 ---
cred = credentials.Certificate("hackthon-techtechtechnology-adminsdk.json")
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred, {
        'databaseURL': 'https://hackthon-techtechtechnology-default-rtdb.firebaseio.com/'
    })

# --- 4. エンドポイント ---

@app.get("/game-status")
def get_game_status():
    """現在のステージと敵のHPを取得（セーブデータ読み込み）"""
    db_session = SessionLocal()
    status = db_session.query(GameStatus).first()
    db_session.close()
    return status

@app.post("/attack")
def attack_enemy(damage: int):
    """ダメージを与え、セーブデータを更新する"""
    db_session = SessionLocal()
    status = db_session.query(GameStatus).first()
    
    if status:
        # HPを減らす
        status.current_hp -= damage
        
        # 敵を倒した判定
        if status.current_hp <= 0:
            status.stage += 1
            # 次のステージのHP設定（例：ステージごとに50ずつ増える）
            status.max_hp = 100 + (status.stage - 1) * 50
            status.current_hp = status.max_hp
            
            # ステージ5を超えたらワールドアップ（任意）
            if status.stage > 5:
                status.world += 1
                status.stage = 1
        
        db_session.commit()
        # 更新後の値をコピーして返す（セッションを閉じる前に）
        res = {
            "world": status.world,
            "stage": status.stage,
            "current_hp": status.current_hp,
            "max_hp": status.max_hp
        }
        db_session.close()
        return res
    
    db_session.close()
    return {"error": "Game status not found"}

@app.get("/check-firebase")
def check_firebase():
    ref = db.reference('/sensor')
    data = ref.get()
    return {"firebase_data": data}

@app.get("/history")
def get_history():
    db_session = SessionLocal()
    records = db_session.query(BreathHistory).order_by(BreathHistory.created_at.desc()).limit(100).all()
    db_session.close()
    return records

# --- 監視スレッド関連 ---
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
        print(f"Error during auto-sync: {e}")

@app.on_event("startup")
def startup_event():
    listener_thread = threading.Thread(target=lambda: db.reference('/sensor').listen(lambda event: save_to_postgres(event.data)), daemon=True)
    listener_thread.start()