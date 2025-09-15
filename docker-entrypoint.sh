#!/bin/sh
set -e

# Set default database path if not provided
if [ -z "$DATABASE_PATH" ]; then
    export DATABASE_PATH="/app/data/study_bot.db"
fi

# Generate secret key base if not provided
if [ -z "$SECRET_KEY_BASE" ]; then
    echo "Generating SECRET_KEY_BASE..."
    export SECRET_KEY_BASE=$(openssl rand -base64 48)
fi

# Initialize database if it doesn't exist (as root to ensure permissions)
if [ ! -f "$DATABASE_PATH" ]; then
    echo "Initializing database..."
    /app/bin/migrate
    # Fix ownership after creating database
    chown nobody:nogroup "$DATABASE_PATH"
    echo "Database initialized successfully"
fi

# Ensure data directories have correct ownership
chown -R nobody:nogroup /app/data /app/chroma_data

# Start ChromaDB in the background first
echo "Starting ChromaDB..."
export CHROMA_DB_IMPL="duckdb+parquet"
export CHROMA_PERSIST_DIRECTORY="/app/chroma_data"
export ALLOW_RESET="TRUE"
chroma run --host localhost --port 8000 --path /app/chroma_data &

# Wait for ChromaDB to be ready
echo "Waiting for ChromaDB to be ready..."
sleep 5
while ! curl -s http://localhost:8000 > /dev/null; do
    echo "Waiting for ChromaDB..."
    sleep 2
done
echo "ChromaDB is ready!"

echo "Starting Phoenix server with supervisor..."

# Execute the main command
exec "$@"