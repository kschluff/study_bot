#!/bin/bash

set -e

echo "🛑 StudyBot Auto-Start Removal"
echo "=============================="

PLIST_FILE="$HOME/Library/LaunchAgents/com.studybot.app.plist"

# Check if LaunchAgent exists
if [ ! -f "$PLIST_FILE" ]; then
    echo "ℹ️  StudyBot auto-start is not installed."
    exit 0
fi

# Stop and unload the service
echo "🔄 Stopping StudyBot service..."
launchctl stop com.studybot.app 2>/dev/null || true
launchctl unload "$PLIST_FILE" 2>/dev/null || true

# Remove the plist file
echo "🗑️  Removing LaunchAgent configuration..."
rm -f "$PLIST_FILE"

# Also stop any running containers
echo "🐳 Stopping Docker containers..."
docker compose down 2>/dev/null || true

echo "✅ StudyBot auto-start has been removed."
echo ""
echo "ℹ️  To re-enable auto-start, run: ./install-autostart.sh"