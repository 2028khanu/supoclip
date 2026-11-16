#!/bin/bash
# Run SupoClip natively (no Docker): Postgres + Redis + backend + worker + frontend.
cd "$(dirname "$0")"
set -a; source .env; set +a
mkdir -p logs uploads
pg_ctlcluster 16 main start 2>/dev/null || true
redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes >/dev/null

export REDIS_HOST=127.0.0.1 REDIS_PORT=6379 TEMP_DIR="$PWD/uploads"
(cd backend && DATABASE_URL=postgresql+asyncpg://supoclip:supoclip_password@127.0.0.1:5432/supoclip \
  nohup .venv/bin/uvicorn src.main:app --host 0.0.0.0 --port 8000 > ../logs/backend.log 2>&1 &)
(cd backend && DATABASE_URL=postgresql+asyncpg://supoclip:supoclip_password@127.0.0.1:5432/supoclip \
  nohup .venv/bin/python -m src.workers.run_workers > ../logs/worker.log 2>&1 &)
(cd frontend && DATABASE_URL=postgresql://supoclip:supoclip_password@127.0.0.1:5432/supoclip \
  NEXT_PUBLIC_API_URL=http://localhost:8000 BACKEND_INTERNAL_URL=http://localhost:8000 \
  NEXT_PUBLIC_SELF_HOST="${SELF_HOST:-true}" NEXT_TELEMETRY_DISABLED=1 \
  nohup pnpm dev > ../logs/frontend.log 2>&1 &)
echo "Frontend: http://localhost:3107   Backend: http://localhost:8000/docs   Logs: ./logs"
