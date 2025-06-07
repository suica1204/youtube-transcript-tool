#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}YouTube Transcript Tool Setup${NC}"
echo "=================================="

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script is for macOS only"
    exit 1
fi

echo "📦 Installing dependencies..."

if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Installing ffmpeg..."
    brew install ffmpeg
fi

echo "Installing Python packages..."
pip3 install yt-dlp
python3 -c "import ssl; ssl._create_default_https_context = ssl._create_unverified_context; import subprocess; subprocess.run(['pip3', 'install', 'openai-whisper'])"

echo "Setting up directories..."
mkdir -p "$HOME/Documents/youtube-transcripts"/{raw-audio,transcripts,markdown}

echo "Installing shell function..."
cat >> ~/.zshrc << 'EOL'

youtube_transcript() {
    local url=$1
    
    if [ -z "$url" ]; then
        echo "Usage: youtube_transcript \"https://youtube.com/watch?v=...\""
        return 1
    fi
    
    local base_dir="$HOME/Documents/youtube-transcripts"
    mkdir -p "$base_dir"/{raw-audio,transcripts,markdown}
    
    echo "🎥 Starting: $url"
    cd "$base_dir"
    
    if python3 -m yt_dlp --no-check-certificate -x --audio-format wav "$url" --output "raw-audio/%(title)s.%(ext)s"; then
        echo "✅ Audio download completed"
    else
        echo "❌ Download failed"
        return 1
    fi
    
    local audio_file=$(ls -t raw-audio/*.wav 2>/dev/null | head -1)
    if [ -z "$audio_file" ]; then
        echo "❌ No audio file found"
        return 1
    fi
    
    echo "🎤 Starting transcription..."
    if python3 -m whisper "$audio_file" --language en --model medium --output_dir transcripts; then
        echo "✅ Completed! Files at: $base_dir"
    else
        echo "❌ Transcription failed"
        return 1
    fi
}
EOL

echo -e "${GREEN}✅ Setup completed!${NC}"
echo "🔄 Run: source ~/.zshrc"
echo "📝 Usage: youtube_transcript \"URL\""
