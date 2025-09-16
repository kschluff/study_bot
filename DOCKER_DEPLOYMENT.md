# Docker Deployment Guide

This guide explains how to deploy StudyBot with Docker using a single container that runs both the Phoenix release and an embedded ChromaDB instance.

## Overview

- **Service**: The `study_bot` container (defined in `docker-compose.yml`) hosts Phoenix and ChromaDB. Phoenix exposes port 4000; ChromaDB listens on localhost:8000 inside the container.
- **Orchestration**: Docker Compose builds the release image from `Dockerfile` and starts the container. The entrypoint script launches ChromaDB, waits for it to become healthy, and then starts Phoenix as the `nobody` user.
- **Persistence**: Host bind mounts provide durable storage:
  - `./data` ⇄ `/app/data` (SQLite database)
  - `./chroma_data` ⇄ `/app/chroma_data` (ChromaDB files)
- **Health checks**: Phoenix responds to `HEAD /health`, which the Compose health probe calls.

## Prerequisites

1. Docker engine or Docker Desktop with Compose v2
2. `OPENAI_API_KEY` (required). `ANTHROPIC_API_KEY` is optional.

## Quick Start

1. Create a `.env` file in the project root:

   ```bash
   cat > .env <<'ENV'
   OPENAI_API_KEY=replace-with-your-key
   # Optional
   # ANTHROPIC_API_KEY=replace-with-your-key
   # SECRET_KEY_BASE=provide-if-you-want-a-static-value
   ENV
   ```

2. Build and run the container:

   ```bash
   docker compose up --build
   ```

3. Open [http://localhost:4000](http://localhost:4000) to use StudyBot.

## Useful Commands

```bash
# Container status and health
docker compose ps

# Follow logs (Phoenix + Chroma output)
docker compose logs -f study_bot

# Stop and remove container
docker compose down

# Rebuild the image after code changes
docker compose build study_bot
```

## Environment Variables

`docker-compose.yml` automatically loads values from `.env`.

| Variable | Required | Description |
| --- | --- | --- |
| `OPENAI_API_KEY` | Yes | Used for embeddings (and chat when using OpenAI) |
| `ANTHROPIC_API_KEY` | No | Required only if Anthropic is configured at compile time |
| `SECRET_KEY_BASE` | No | Generated automatically when omitted |
| `PHX_HOST` | No | Defaults to `localhost`; used for origin checks |
| `PORT` | No | Defaults to `4000` |
| `CHROMA_PERSIST_DIRECTORY` | No | Defaults to `/app/chroma_data` |

## Container Details

- `docker-entrypoint.sh` prepares `/app/data`, runs database migrations, starts ChromaDB (`chroma run --host 127.0.0.1 --port 8000 --path /app/chroma_data`), waits for the `/api/v2/heartbeat`, and finally launches the Phoenix release (`/app/bin/server`) via `gosu` so it runs as `nobody`.
- Phoenix connects to Chroma through `http://localhost:8000` (`CHROMA_BASE_URL`).
- Port 4000 is the only port published to the host.

## Troubleshooting

- **Missing API key**: Ensure `OPENAI_API_KEY` exists in `.env`, then rebuild: `docker compose down && docker compose up --build`.
- **Chroma startup issues**: Check `docker compose logs study_bot` for “ChromaDB is ready”. If startup loops, remove `./chroma_data` and restart.
- **Database problems**: Delete `./data/study_bot.db` and restart; migrations run automatically inside the entrypoint.
- **Updating code**: Rebuild the image after code changes to Phoenix, Chroma setup, or assets: `docker compose build study_bot`.

## Files of Interest

```
Dockerfile            # Multi-stage Phoenix + Chroma image build
DOCKER_DEPLOYMENT.md  # This guide
docker-compose.yml    # Service definition
docker-entrypoint.sh  # Startup script (migrations + Chroma + Phoenix)
supervisord.conf      # Legacy supervisor config kept for reference
```

With the container running, Phoenix and Chroma communicate internally, while only Phoenix is exposed on port 4000.
