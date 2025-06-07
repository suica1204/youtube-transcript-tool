#!/bin/bash

set -e

echo "📥 Installing YouTube Transcript Tool..."

if [ ! -d "youtube-transcript-tool" ]; then
    git clone https://github.com/suica1204/youtube-transcript-tool.git
fi

cd youtube-transcript-tool
chmod +x setup.sh
./setup.sh

echo "✅ Installation completed!"
