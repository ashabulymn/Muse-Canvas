# Muse-Canvas (fork) — deploy Dokploy canvas-only
# Hanya server statis kanvas (canvas_server.py + canvas/dist).
# Tanpa Chromium, tanpa Node. muse2api dipakai dari layanan live terpisah,
# Agent DeepSeek tidak ikut di image ini.
FROM python:3.11-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    CANVAS_HOST=0.0.0.0 \
    CANVAS_PORT=521

WORKDIR /app

COPY canvas_server.py ./
COPY canvas/dist/ ./canvas/dist/

EXPOSE 521

CMD ["python", "canvas_server.py"]
