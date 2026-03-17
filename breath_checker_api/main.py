import os
import datetime
import threading
from fastapi import FastAPI
import firebase_admin
from firebase_admin import credentials, db
from sqlalchemy import create_engine, Column, Integer, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

app = FastAPI()

# --- 1. Cloud SQL 接続情報 (ここにメモした情報を入れる) ---
DB_USER = "postgres"
DB_PASS = "techtech"
DB_IP   = "104.198.121.0"
DB_NAME = "postgres" # または作成したDB名

# SQLAlchemy用の接続文字列
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASS}@{DB_IP}/{DB_NAME}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# --- 2. テーブル定義 ---
class BreathHistory(Base):
    __tablename__ = "breath_history"
    id = Column(Integer, primary_key=True, index=True)
    temperature = Column(Float)
    humidity = Column(Float)
    gas_resistance = Column(Float)
    diff_percent = Column(Float)
    created_at = Column(DateTime, default=datetime.datetime.now)

Base.metadata.create_all(bind=engine)

# --- 3. Firebase 初期化 ---
cred = credentials.Certificate("hackthon-techtechtechnology-adminsdk.json")
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred, {
        'databaseURL': 'https://hackthon-techtechtechnology-default-rtdb.firebaseio.com/'
    })

# --- 4. 各エンドポイント（道） ---

@app.get("/")
def read_root():
    return {"message": "API is running", "available_endpoints": ["/sync", "/check-firebase"]}

def save_to_postgres(data):
    """Firebaseから来たデータをDBに保存する共通関数"""
    if not data:
        return
    
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
        print(f"Successfully auto-synced: {data}")
    except Exception as e:
        print(f"Error during auto-sync: {e}")

def firebase_listener():
    """Firebaseの値をずっと見張る関数"""
    # '/sensor' パスのデータが更新されたら save_to_postgres を呼ぶ
    db.reference('/sensor').listen(lambda event: save_to_postgres(event.data))

# FastAPIが起動した瞬間に、別スレッドで監視を開始する
@app.on_event("startup")
def startup_event():
    # サーバーのメイン処理を邪魔しないように threading を使う
    listener_thread = threading.Thread(target=firebase_listener, daemon=True)
    listener_thread.start()
    print("Firebase listener started!")

# 以下の手動エンドポイントも残しておくと便利です
@app.get("/history")
def get_history():
    db_session = SessionLocal()
    records = db_session.query(BreathHistory).order_by(BreathHistory.created_at.desc()).limit(100).all()
    db_session.close()
    return records

@app.get("/check-firebase")
def check_firebase():
    """DBには保存せず、Firebaseの中身を見るだけ"""
    ref = db.reference('/sensor')
    data = ref.get()
    return {"firebase_data": data}

@app.get("/sync")
def sync_data():
    """Firebaseから取ってPostgreSQLに保存する"""
    ref = db.reference('/sensor')
    data = ref.get()
    
    if data:
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
        return {"status": "success", "saved_data": data}
    return {"status": "no data in firebase"}

@app.get("/history")
def get_history():
    """PostgreSQLに保存された履歴をすべて取得して返す"""
    db_session = SessionLocal()
    # 全データを取得（新しい順）
    records = db_session.query(BreathHistory).order_by(BreathHistory.created_at.desc()).all()
    db_session.close()
    return records