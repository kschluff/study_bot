# Auto-Start StudyBot on Mac Boot

This guide provides multiple methods to automatically start StudyBot when your Mac boots up.

## Method 1: Automated Installation (Recommended)

The simplest way to enable auto-start:

```bash
# Set your API key
export OPENAI_API_KEY="your-openai-api-key-here"

# Install auto-start
./install-autostart.sh
```

This creates a macOS LaunchAgent that will start StudyBot automatically when you log in.

### Managing Auto-Start

```bash
# Check status
launchctl list | grep studybot

# Start manually
launchctl start com.studybot.app

# Stop
launchctl stop com.studybot.app

# Disable auto-start
./uninstall-autostart.sh

# Re-enable auto-start
./install-autostart.sh
```

## Method 2: Manual LaunchAgent Setup

If you prefer manual setup:

1. **Copy the template**:
   ```bash
   cp com.studybot.app.plist ~/Library/LaunchAgents/
   ```

2. **Edit the file**:
   ```bash
   nano ~/Library/LaunchAgents/com.studybot.app.plist
   ```
   
   Update these values:
   - Replace `YOUR_USERNAME` with your actual username
   - Replace `/path/to/study_bot` with the full path to your StudyBot directory
   - Replace `YOUR_OPENAI_API_KEY` with your actual API key

3. **Load the agent**:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.studybot.app.plist
   ```

## Method 3: Docker Desktop Auto-Start

Enable Docker Desktop to start with macOS:

1. Open Docker Desktop
2. Go to **Settings** → **General**
3. Check "Start Docker Desktop when you log in"
4. Add restart policy to docker-compose.yml:
   ```yaml
   services:
     study_bot:
       restart: unless-stopped
   ```

Then manually start StudyBot once:
```bash
docker compose up -d
```

## Method 4: Login Items (GUI Method)

1. **System Settings** → **General** → **Login Items**
2. Click the **+** button under "Open at Login"
3. Navigate to and select your `deploy.sh` script
4. The script will run automatically at login

## How It Works

The LaunchAgent method:

- **Runs at login**: Starts when you log in to your Mac user account
- **User-level service**: Runs under your user account (not system-wide)
- **Automatic restart**: Can restart the service if it fails
- **Environment variables**: Securely stores your API keys
- **Logging**: Outputs logs to `~/Library/Logs/StudyBot/`

## Troubleshooting

### Check if auto-start is working:
```bash
# List running launch agents
launchctl list | grep studybot

# Check recent logs
tail -f ~/Library/Logs/StudyBot/studybot.log
```

### Common issues:

1. **Docker not found**: Make sure Docker Desktop is installed and running
2. **Permission denied**: Ensure scripts have execute permissions (`chmod +x`)
3. **API key missing**: Verify OPENAI_API_KEY is set in the LaunchAgent plist
4. **Path issues**: Use absolute paths in the LaunchAgent configuration

### Force restart the service:
```bash
launchctl stop com.studybot.app
launchctl start com.studybot.app
```

### Completely reset auto-start:
```bash
./uninstall-autostart.sh
./install-autostart.sh
```

## Log Files

Auto-start logs are saved to:
- **Standard output**: `~/Library/Logs/StudyBot/studybot.log`
- **Errors**: `~/Library/Logs/StudyBot/studybot.error.log`

View logs:
```bash
# Live output
tail -f ~/Library/Logs/StudyBot/studybot.log

# Recent errors
tail -20 ~/Library/Logs/StudyBot/studybot.error.log
```

## Security Considerations

- API keys are stored in the LaunchAgent plist file
- Plist files are readable only by your user account
- Consider using environment variables or a secure key management system for production

## Alternative: System-Wide Auto-Start

For system-wide auto-start (runs before user login):

1. Create LaunchDaemon instead of LaunchAgent
2. Place plist in `/Library/LaunchDaemons/`
3. Requires admin privileges and different security considerations

This is not recommended for personal development setups.