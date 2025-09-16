#!/bin/sh
set -e

DATABASE_PATH="${DATABASE_PATH:-/app/data/study_bot.db}"
CHROMA_DIR="${CHROMA_PERSIST_DIRECTORY:-/app/chroma_data}"

export DATABASE_PATH
export CHROMA_PERSIST_DIRECTORY="$CHROMA_DIR"
export CHROMA_DB_IMPL="duckdb+parquet"
export ALLOW_RESET="TRUE"

DATA_DIR="$(dirname "$DATABASE_PATH")"

mkdir -p "$DATA_DIR" "$CHROMA_DIR"
if ! chown -R nobody:nogroup "$DATA_DIR" "$CHROMA_DIR"; then
    echo "Warning: could not change ownership of $DATA_DIR or $CHROMA_DIR; continuing"
fi

if [ ! -f "$DATABASE_PATH" ]; then
    echo "Running database migrations..."
    gosu nobody /app/bin/migrate
    echo "Database ready"
fi

echo "Starting ChromaDB..."
gosu nobody chroma run --host 127.0.0.1 --port 8000 --path "$CHROMA_DIR" &
CHROMA_PID=$!

cleanup() {
    if [ -n "$CHROMA_PID" ]; then
        kill "$CHROMA_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

for _ in $(seq 1 30); do
    if curl -fsS http://127.0.0.1:8000/api/v2/heartbeat >/dev/null 2>&1; then
        echo "ChromaDB is ready"
        break
    fi
    sleep 1
done

echo "Starting StudyBot release"
exec gosu nobody "$@"
