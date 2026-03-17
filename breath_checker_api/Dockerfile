# Pythonの軽量版イメージを使用
FROM python:3.12-slim

# 作業ディレクトリを設定
WORKDIR /app

# 必要なファイルをコピー
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ソースコードをコピー
COPY . .

# ポート8080で起動（Cloud Runのデフォルト）
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]