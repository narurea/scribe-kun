#!/bin/sh
# Generates Transcribe.xcodeproj from project.yml.
set -eu
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen が見つかりません。'brew install xcodegen' でインストールしてください。" >&2
    exit 1
fi

xcodegen generate
echo "Transcribe.xcodeproj を生成しました。'open Transcribe.xcodeproj' で開けます。"
