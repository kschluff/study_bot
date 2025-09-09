#!/bin/bash

set -e

echo "🚀 StudyBot Deployment Script for M4 Mac"
echo "========================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

# Check for required environment variables
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ OPENAI_API_KEY environment variable is required"
    echo "   Set it with: export OPENAI_API_KEY=your_key_here"
    exit 1
fi

# Generate SECRET_KEY_BASE if not set
if [ -z "$SECRET_KEY_BASE" ]; then
    echo "🔑 Generating SECRET_KEY_BASE..."
    export SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -d '\n')
fi

# Set default PHX_HOST if not provided
export PHX_HOST=${PHX_HOST:-localhost}

echo "📦 Building Docker image for M4 Mac..."
docker-compose build --pull

echo "🗂️  Creating data directories..."
mkdir -p data chroma_data

echo "🔥 Starting services..."
docker-compose up -d

echo "⏳ Waiting for services to start..."
sleep 10

# Wait for the application to be healthy
echo "🏥 Checking application health..."
timeout 60 bash -c 'until curl -f http://localhost:4000/health > /dev/null 2>&1; do echo "Waiting for app..."; sleep 5; done' || {
    echo "❌ Application failed to start properly"
    echo "📋 Checking logs..."
    docker-compose logs --tail=50
    exit 1
}

echo "✅ StudyBot is running!"
echo "🌐 Access the application at: http://localhost:4000"
echo ""
echo "📋 Useful commands:"
echo "   View logs: docker-compose logs -f"
echo "   Stop services: docker-compose down"
echo "   Restart: docker-compose restart"
echo "   Rebuild: docker-compose build && docker-compose up -d"
echo ""
echo "💾 Data is persisted in ./data and ./chroma_data directories"