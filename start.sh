#!/bin/bash

set -e

# Function to reset the project
reset_project() {
    echo "🔄 Resetting StudyBot project..."
    
    # Delete ChromaDB database
    if [ -d "./chroma" ]; then
        echo "🗑️  Deleting ChromaDB database..."
        rm -rf ./chroma
        echo "✅ ChromaDB database deleted"
    fi
    
    # Reset Ecto database
    echo "🗃️  Resetting Ecto database..."
    mix ecto.reset
    echo "✅ Ecto database reset complete"
    
    echo "🎉 Project reset complete!"
}

# Check for reset flag
if [ "$1" = "--reset" ] || [ "$1" = "-r" ]; then
    reset_project
    exit 0
fi

echo "🚀 Starting StudyBot services..."

# Check for required environment variable
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY environment variable is not set"
    echo "Please set your OpenAI API key: export OPENAI_API_KEY=your_key_here"
    exit 1
fi

echo "✅ OPENAI_API_KEY is set"

# Check and activate Python virtual environment
if [ ! -d "./venv" ]; then
    echo "❌ Error: Python virtual environment not found at ./venv"
    echo "Please create a virtual environment: python -m venv venv"
    exit 1
fi

echo "🐍 Activating Python virtual environment..."
source ./venv/bin/activate

# Start ChromaDB in the background
echo "🔧 Starting ChromaDB..."
if command -v chroma &> /dev/null; then
    chroma run --host localhost --port 8000 --path ./chroma &
    CHROMA_PID=$!
    echo "✅ ChromaDB started (PID: $CHROMA_PID)"
else
    echo "❌ Error: ChromaDB not found. Please install with: pip install chromadb"
    exit 1
fi

# Function to cleanup background processes on exit
cleanup() {
    echo "🛑 Shutting down services..."
    if [ ! -z "$CHROMA_PID" ]; then
        kill $CHROMA_PID 2>/dev/null || true
        echo "✅ ChromaDB stopped"
    fi
}

# Set trap to cleanup on script exit
trap cleanup EXIT

# Wait a moment for ChromaDB to start
echo "⏳ Waiting for ChromaDB to initialize..."
sleep 3

# Start Phoenix server
echo "🔥 Starting Phoenix server..."
mix phx.server