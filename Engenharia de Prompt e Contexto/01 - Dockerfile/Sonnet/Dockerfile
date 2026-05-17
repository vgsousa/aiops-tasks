FROM python:3.12-slim

WORKDIR /app

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY lib/ lib/

USER appuser

ENV DATABASE_URL=""
ENV API_KEY=""

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "app:app"]
