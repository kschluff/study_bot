#!/bin/sh
set -e

DATABASE_PATH="${DATABASE_PATH:-/app/data/study_bot.db}"
export DATABASE_PATH
DATA_DIR="$(dirname "$DATABASE_PATH")"

mkdir -p "$DATA_DIR"
if ! chown -R nobody:nogroup "$DATA_DIR"; then
    echo "Warning: could not change ownership of $DATA_DIR; continuing"
fi

if [ ! -f "$DATABASE_PATH" ]; then
    echo "Running database migrations..."
    gosu nobody /app/bin/migrate
    echo "Database ready"
fi

echo "Starting StudyBot release"
exec gosu nobody "$@"
