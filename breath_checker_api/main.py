import os
import datetime
import threading
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, db
from sqlalchemy import create_engine, Column, Integer, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
    DB_IP = "104.198.121.0"
    DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASS}@{DB_IP}/{DB_NAME}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# 履歴テーブル (PostgreSQLは「記録」のために残す)
class BreathHistory(Base):
    __tablename__ = "breath_history"
    id = Column(Integer, primary_key=True, index=True)
    temperature = Column(Float)
    humidity = Column(Float)
    gas_resistance = Column(Float)
    diff_percent = Column(Float)
    created_at = Column(DateTime, default=datetime.datetime.now)

Base.metadata.create_all(bind=engine)

# --- 2. Firebase 初期化 ---
cred = credentials.Certificate("hackthon-techtechtechnology-adminsdk.json")
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred, {
        'databaseURL': 'https://hackthon-techtechtechnology-default-rtdb.firebaseio.com/'
    })

# --- 3. エンドポイント ---

@app.get("/game-status")
def get_status():
    """Firebaseから最新のゲーム状況を取得"""
    ref = db.reference('game_status')
    data = ref.get()
    if not data:
        return {"world": 1, "stage": 1, "current_hp": 100, "max_hp": 100}
    return data

@app.post("/attack")
def attack_enemy(damage: int):
    """Firebaseのデータを更新して攻撃処理を行う"""
    ref = db.reference('game_status')
    status = ref.get() or {"world": 1, "stage": 1, "current_hp": 100, "max_hp": 100}
    
    current_hp = status.get("current_hp", 100) - damage
    stage = status.get("stage", 1)
    world = status.get("world", 1)
    max_hp = status.get("max_hp", 100)

    if current_hp <= 0:
        stage += 1
        max_hp = 100 + (stage - 1) * 50
        current_hp = max_hp
        if stage > 5:
            world += 1
            stage = 1
            
    new_status = {
        "world": world,
        "stage": stage,
        "current_hp": current_hp,
        "max_hp": max_hp
    }
    ref.set(new_status) # Firebaseを更新
    return new_status

@app.post("/reset-game")
def reset_game():
    """Firebaseを初期状態にリセット"""
    try:
        ref = db.reference('game_status')
        initial_data = {"world": 1, "stage": 1, "current_hp": 100, "max_hp": 100}
        ref.set(initial_data)
        return {"message": "Success", "data": initial_data}
    except Exception as e:
        return {"error": str(e)}, 500

@app.get("/check-firebase")
def check_firebase():
    return {"firebase_data": db.reference('/sensor').get()}

@app.get("/history")
def get_history():
    db_session = SessionLocal()
    records = db_session.query(BreathHistory).order_by(BreathHistory.created_at.desc()).limit(100).all()
    db_session.close()
    return records

# --- 4. 履歴保存スレッド (Firebase -> PostgreSQL) ---
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
    threading.Thread(target=lambda: db.reference('/sensor').listen(lambda event: save_to_postgres(event.data)), daemon=True).start()

# --- 1. テーブル定義に追加 ---
class BattleLog(Base):
    __tablename__ = "battle_log"
    id = Column(Integer, primary_key=True, index=True)
    world = Column(Integer)
    stage = Column(Integer)
    damage = Column(Integer)
    diff_percent = Column(Float)  # その時の汚れ除去率
    created_at = Column(DateTime, default=datetime.datetime.now)

# テーブル作成を実行（既存のテーブルは維持されます）
Base.metadata.create_all(bind=engine)

# --- 2. 攻撃エンドポイントを修正 ---
@app.post("/attack")
def attack_enemy(damage: int):
    # Firebaseから現在のステータスを取得
    ref = db.reference('game_status')
    status = ref.get() or {"world": 1, "stage": 1, "current_hp": 100, "max_hp": 100}
    
    # --- 戦闘ログを PostgreSQL に保存 ---
    db_session = SessionLocal()
    try:
        new_log = BattleLog(
            world=status.get("world", 1),
            stage=status.get("stage", 1),
            damage=damage,
            diff_percent=status.get("diff_percent", 0), # 必要ならセンサー値を取得
            created_at=datetime.datetime.now()
        )
        db_session.add(new_log)
        db_session.commit()
    except Exception as e:
        print(f"SQL Save Error: {e}")
    finally:
        db_session.close()

    # --- 以下、これまでのHP計算とFirebase更新処理 ---
    current_hp = status.get("current_hp", 100) - damage
    stage = status.get("stage", 1)
    world = status.get("world", 1)
    max_hp = status.get("max_hp", 100)

    if current_hp <= 0:
        stage += 1
        max_hp = 100 + (stage - 1) * 50
        current_hp = max_hp
        if stage > 5:
            world += 1
            stage = 1
            
    new_status = {"world": world, "stage": stage, "current_hp": current_hp, "max_hp": max_hp}
    ref.set(new_status)
    return new_status

# --- 3. ログ取得用のエンドポイントを追加 ---
@app.get("/battle-history")
def get_battle_history():
    db_session = SessionLocal()
    # 直近50件の戦闘ログを取得
    logs = db_session.query(BattleLog).order_by(BattleLog.created_at.desc()).limit(50).all()
    db_session.close()
    return logs