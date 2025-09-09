# Docker Deployment for StudyBot on M4 Mac

This guide provides Docker deployment for StudyBot with embedded ChromaDB, optimized for M4 Mac (Apple Silicon).

## Architecture

- **Single Container**: Phoenix application and ChromaDB run in the same container
- **Supervisor**: Uses supervisord to manage both services
- **Internal Communication**: ChromaDB runs on localhost:8000 (not exposed externally)
- **Data Persistence**: SQLite and ChromaDB data are persisted via Docker volumes

## Prerequisites

1. **Docker Desktop**: Install Docker Desktop for Mac (Apple Silicon version)
2. **API Keys**: OpenAI API key (required for embeddings)

## Quick Start

1. **Set up environment variables**:
   ```bash
   export OPENAI_API_KEY="your-openai-api-key-here"
   # Optional: export ANTHROPIC_API_KEY="your-anthropic-api-key-here"
   ```

2. **Run the deployment script**:
   ```bash
   ./deploy.sh
   ```

3. **Access the application**:
   - Open http://localhost:4000 in your browser

## Manual Deployment

If you prefer manual deployment:

1. **Copy environment file**:
   ```bash
   cp .env.example .env
   # Edit .env with your API keys
   ```

2. **Build and start**:
   ```bash
   docker compose build
   docker compose up -d
   ```

3. **Check status**:
   ```bash
   docker compose ps
   docker compose logs -f
   ```

## File Structure

```
├── Dockerfile                 # Multi-stage build for Phoenix + ChromaDB
├── docker-compose.yml         # Service configuration
├── supervisord.conf          # Process management for Phoenix + ChromaDB
├── docker-entrypoint.sh      # Startup script with DB initialization
├── deploy.sh                 # Automated deployment script
├── .dockerignore             # Files to exclude from Docker context
└── .env.example              # Environment variable template
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | Yes | - | OpenAI API key for embeddings and chat |
| `ANTHROPIC_API_KEY` | No | - | Anthropic API key (if using Anthropic provider) |
| `SECRET_KEY_BASE` | No | auto-generated | Phoenix secret key |
| `PHX_HOST` | No | localhost | Phoenix host |
| `PORT` | No | 4000 | Phoenix port |

## Data Persistence

- **SQLite Database**: `./data/study_bot.db`
- **ChromaDB Data**: `./chroma_data/`

These directories are automatically created and mounted as Docker volumes.

## Container Services

The container runs two services via supervisord:

1. **ChromaDB**: Vector database on localhost:8000 (internal only)
2. **Phoenix**: Web application on port 4000 (exposed)

## Troubleshooting

### Check service status:
```bash
docker compose ps
```

### View logs:
```bash
# All services
docker compose logs -f

# Phoenix only
docker compose logs -f study_bot

# ChromaDB specifically
docker compose exec study_bot tail -f /var/log/supervisor/chromadb.out.log
```

### Restart services:
```bash
docker compose restart
```

### Clean rebuild:
```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Database issues:
```bash
# Reset database
docker compose exec study_bot rm -f /app/data/study_bot.db
docker compose restart
```

## Health Checks

The container includes health checks that verify:
- Phoenix server responds on port 4000
- Application is ready to serve requests

Check health status:
```bash
docker compose ps
# Look for "healthy" status
```

## Performance Notes for M4 Mac

- Uses Alpine Linux base image for smaller size
- Multi-architecture support for ARM64
- Optimized build layers for faster rebuilds
- Persistent data volumes for faster restarts

## Security Notes

- ChromaDB port (8000) is not exposed outside the container
- Only Phoenix port (4000) is accessible from host
- Environment variables for sensitive data (API keys)
- No root processes in production workload