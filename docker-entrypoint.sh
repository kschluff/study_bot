#!/bin/sh
set -e

# Generate secret key base if not provided
if [ -z "$SECRET_KEY_BASE" ]; then
    echo "Generating SECRET_KEY_BASE..."
    export SECRET_KEY_BASE=$(mix phx.gen.secret)
fi

# Initialize database if it doesn't exist
if [ ! -f /app/data/study_bot.db ]; then
    echo "Initializing database..."
    mix ecto.create
    mix ecto.migrate
    mix run priv/repo/seeds.exs
fi

# Wait for ChromaDB to be ready (it will be started by supervisor)
echo "Starting services with supervisor..."

# Execute the main command
exec "$@"