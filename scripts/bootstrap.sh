#!/bin/sh
# Generates Transcribe.xcodeproj from project.yml.
# Uses xcodegen from PATH if installed; otherwise downloads a pinned release into .tools/
# (no Homebrew needed).
set -eu
cd "$(dirname "$0")/.."

XCODEGEN_VERSION="2.46.0"
XCODEGEN_SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
TOOLS_DIR=".tools/xcodegen-$XCODEGEN_VERSION"

if command -v xcodegen >/dev/null 2>&1; then
    XCODEGEN="xcodegen"
else
    XCODEGEN="$TOOLS_DIR/xcodegen/bin/xcodegen"
    if [ ! -x "$XCODEGEN" ]; then
        echo "XcodeGen $XCODEGEN_VERSION をダウンロードしています…"
        mkdir -p "$TOOLS_DIR"
        zip="$TOOLS_DIR/xcodegen.zip"
        curl -fL --progress-bar -o "$zip" \
            "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip"
        actual="$(shasum -a 256 "$zip" | awk '{print $1}')"
        if [ "$actual" != "$XCODEGEN_SHA256" ]; then
            echo "ダウンロードしたファイルのチェックサムが一致しません（$actual）" >&2
            rm -f "$zip"
            exit 1
        fi
        unzip -q -o "$zip" -d "$TOOLS_DIR"
        rm -f "$zip"
    fi
fi

"$XCODEGEN" generate
echo "Transcribe.xcodeproj を生成しました。'open Transcribe.xcodeproj' で開けます。"
