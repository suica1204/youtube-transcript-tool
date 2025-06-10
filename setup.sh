cat > setup.sh << 'EOF'
#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🎥 YouTube Transcript Tool Setup${NC}"
echo "=================================="

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script is for macOS only"
    exit 1
fi

echo "📦 Installing dependencies..."

# Homebrew installation
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# ffmpeg installation
if ! command -v ffmpeg &> /dev/null; then
    echo "Installing ffmpeg..."
    brew install ffmpeg
fi

echo "Installing/Updating Python packages..."
# yt-dlpを最新版にアップデート
pip3 install --upgrade yt-dlp

# Whisperをインストール（SSL問題への対処）
python3 -c "import ssl; ssl._create_default_https_context = ssl._create_unverified_context; import subprocess; subprocess.run(['pip3', 'install', '--upgrade', 'openai-whisper'])"

echo "Setting up directories..."
mkdir -p "$HOME/Documents/youtube-transcripts"/{raw-audio,transcripts,markdown}

echo "Installing shell function..."

# 既存の関数定義を削除（重複を避けるため）
if grep -q "youtube_transcript()" ~/.zshrc 2>/dev/null; then
    echo -e "${YELLOW}Removing existing function...${NC}"
    # 一時ファイルを作成してyoutube_transcript関数以外を保持
    awk '
    /^youtube_transcript\(\)/ { skip=1 }
    skip && /^}$/ { skip=0; next }
    !skip { print }
    ' ~/.zshrc > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc
fi

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
    
    # ダウンロード処理（エラーハンドリング強化）
    echo "📥 Downloading audio..."
    if python3 -m yt_dlp \
        --no-check-certificate \
        --extract-audio \
        --audio-format wav \
        --audio-quality 0 \
        --output "raw-audio/%(title)s.%(ext)s" \
        --no-playlist \
        --ignore-errors \
        "$url"; then
        echo "✅ Audio download completed"
    else
        echo "❌ Download failed. Trying alternative method..."
        # 代替方法を試す
        if python3 -m yt_dlp \
            --extract-audio \
            --audio-format wav \
            --output "raw-audio/%(title)s.%(ext)s" \
            --no-playlist \
            "$url"; then
            echo "✅ Audio download completed (alternative method)"
        else
            echo "❌ All download methods failed"
            return 1
        fi
    fi
    
    # 最新のaudioファイルを取得
    local audio_file=$(ls -t raw-audio/*.wav 2>/dev/null | head -1)
    if [ -z "$audio_file" ]; then
        echo "❌ No audio file found"
        return 1
    fi
    
    echo "🎤 Starting transcription with file: $(basename "$audio_file")"
    
    # 言語を自動検出に変更（日本語コンテンツに対応）
    if python3 -m whisper "$audio_file" \
        --model medium \
        --output_dir transcripts \
        --output_format txt \
        --output_format vtt \
        --verbose False; then
        echo "✅ Transcription completed!"
        echo "📁 Files saved to: $base_dir"
        echo "📄 Transcript: $base_dir/transcripts/"
        
        # 最新の転写ファイルを表示
        local latest_txt=$(ls -t transcripts/*.txt 2>/dev/null | head -1)
        if [ -n "$latest_txt" ]; then
            echo "📝 Latest transcript: $(basename "$latest_txt")"
        fi
    else
        echo "❌ Transcription failed"
        return 1
    fi
}
EOL

echo -e "${GREEN}✅ Setup completed!${NC}"
echo ""
echo "🔄 To activate the function, run:"
echo "   source ~/.zshrc"
echo ""
echo "📝 Usage:"
echo "   youtube_transcript \"https://youtube.com/watch?v=VIDEO_ID\""
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "   - The function will automatically detect language"
echo "   - Files are saved to ~/Documents/youtube-transcripts/"
echo "   - Use Ctrl+C to stop the process if needed"
EOF