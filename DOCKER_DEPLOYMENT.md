# Docker Deployment Guide

This document describes how to run StudyBot with Docker using the current two-container architecture: one container hosts the Phoenix release and another hosts ChromaDB.

## Overview

- **Services**
  - `study_bot`: Phoenix release built from `Dockerfile`. The release runs as a non-root user and exposes port 4000.
  - `chroma`: Standalone ChromaDB server built from `Dockerfile.chroma`. Exposes port 8000 for Phoenix.
- **Orchestration**: `docker-compose.yml` wires both services together. Phoenix waits for the Chroma health check before starting.
- **Persistence**: Application data persists on the host via bind mounts:
  - `./data` → SQLite database (`study_bot.db`)
  - `./chroma_data` → ChromaDB storage
- **Health checks**: Phoenix replies to `HEAD /health`. Chroma exposes `/api/v2/heartbeat`.

## Prerequisites

1. Docker Desktop (or engine) with Compose v2
2. OpenAI API key (required). Anthropic key is optional.

## Quick Start

1. Create a `.env` file in the repository root:

   ```bash
   cat > .env <<'ENV'
   OPENAI_API_KEY=replace-with-your-key
   # Optional:
   # ANTHROPIC_API_KEY=replace-with-your-key
   # SECRET_KEY_BASE=provide-if-you-want-a-static-value
   ENV
   ```

2. Build and launch the stack:

   ```bash
   docker compose up --build
   ```

   Compose builds the Phoenix release image (multi-stage) and the Chroma image, then starts both services.

3. Visit [http://localhost:4000](http://localhost:4000) to use StudyBot.

## Common Commands

```bash
# View container status and health
docker compose ps

# Follow logs for both services
docker compose logs -f

# Only Phoenix logs (includes LiveView output)
docker compose logs -f study_bot

# Stop and remove containers
docker compose down

# Clean rebuild when dependencies change
docker compose build --no-cache
```

## Environment Variables

`docker-compose.yml` loads `.env` automatically. Important keys:

| Variable | Required | Description |
| --- | --- | --- |
| `OPENAI_API_KEY` | Yes | Used for embeddings (and chat when using OpenAI provider) |
| `ANTHROPIC_API_KEY` | No | Required only if Anthropic is selected at compile time |
| `SECRET_KEY_BASE` | No | Generated automatically when omitted |
| `PHX_HOST` | No | Defaults to `localhost`; used for origin checks |
| `PORT` | No | Defaults to `4000` |

## Service Details

### study_bot (Phoenix)
- Built from `Dockerfile`
- Runs the release via `/app/bin/server`
- Entry point (`docker-entrypoint.sh`) handles database migrations and runs the release as the `nobody` user
- Health check hits `http://localhost:4000/health`
- Mounts `./data` to `/app/data`

### chroma (ChromaDB)
- Built from `Dockerfile.chroma`
- Runs `chroma run --host 0.0.0.0 --port 8000`
- Health check probes `http://localhost:8000/api/v2/heartbeat`
- Mounts `./chroma_data` to `/chroma_data`

## Troubleshooting

- **Phoenix reports missing API key**: Confirm `OPENAI_API_KEY` is in `.env` and rebuild (`docker compose down && docker compose up --build`).
- **Chroma unhealthy**: Ensure port 8000 is free and the health endpoint is reachable. Logs: `docker compose logs chroma`.
- **Database issues**: Delete `./data/study_bot.db` and restart; migrations run automatically.
- **Updating code**: After changes, rebuild Phoenix (`docker compose build study_bot`) so the release reflects updates.

## Files of Interest

```
Dockerfile             # Phoenix release build
Dockerfile.chroma      # Chroma image definition
DOCKER_DEPLOYMENT.md   # This guide
docker-compose.yml     # Service orchestration
docker-entrypoint.sh   # Phoenix startup script
supervisord.conf       # Legacy (unused) supervisor config retained for reference
```

With the stack running, Phoenix and Chroma communicate over the internal Docker network, while only Phoenix is exposed to the host.
