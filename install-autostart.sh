#!/bin/bash

set -e

echo "🚀 StudyBot Auto-Start Installation"
echo "=================================="

# Get current user and working directory
CURRENT_USER=$(whoami)
CURRENT_DIR=$(pwd)

# Verify we're in the correct directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found. Please run this script from the StudyBot directory."
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed or not in PATH"
    exit 1
fi

# Check for required environment variables
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY environment variable is required"
    echo "   Set it with: export OPENAI_API_KEY=your_key_here"
    exit 1
fi

# Create log directory
LOG_DIR="$HOME/Library/Logs/StudyBot"
mkdir -p "$LOG_DIR"

# Create the LaunchAgent plist file
PLIST_FILE="$HOME/Library/LaunchAgents/com.studybot.app.plist"

echo "📝 Creating LaunchAgent configuration..."

cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.studybot.app</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/docker</string>
        <string>compose</string>
        <string>up</string>
        <string>-d</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>$CURRENT_DIR</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>OPENAI_API_KEY</key>
        <string>$OPENAI_API_KEY</string>
        <key>ANTHROPIC_API_KEY</key>
        <string>${ANTHROPIC_API_KEY:-}</string>
        <key>SECRET_KEY_BASE</key>
        <string>${SECRET_KEY_BASE:-}</string>
        <key>PHX_HOST</key>
        <string>${PHX_HOST:-localhost}</string>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin</string>
    </dict>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <false/>
    
    <key>StandardOutPath</key>
    <string>$LOG_DIR/studybot.log</string>
    
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/studybot.error.log</string>
    
    <key>StartInterval</key>
    <integer>30</integer>
</dict>
</plist>
EOF

# Set proper permissions
chmod 644 "$PLIST_FILE"

# Load the LaunchAgent
echo "🔄 Loading LaunchAgent..."
launchctl unload "$PLIST_FILE" 2>/dev/null || true
launchctl load "$PLIST_FILE"

echo "✅ Auto-start installation complete!"
echo ""
echo "📋 StudyBot will now start automatically when you log in."
echo ""
echo "🛠️  Management commands:"
echo "   Start now:     launchctl start com.studybot.app"
echo "   Stop:          launchctl stop com.studybot.app"
echo "   Disable:       launchctl unload ~/Library/LaunchAgents/com.studybot.app.plist"
echo "   Re-enable:     launchctl load ~/Library/LaunchAgents/com.studybot.app.plist"
echo ""
echo "📄 Logs location: $LOG_DIR"
echo "   View logs:     tail -f $LOG_DIR/studybot.log"
echo "   View errors:   tail -f $LOG_DIR/studybot.error.log"
echo ""
echo "🌐 Application will be available at: http://localhost:4000"