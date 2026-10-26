# ビデオから文字起こし（Transcribe）

動画・音声ファイルをウィンドウにドロップするだけで、**Mac の中だけで**文字起こししてテキストファイルに書き出す macOS アプリです。
音声や文字起こし結果を外部に送信することはありません（通信するのは初回のモデルダウンロードだけです）。

- 実装：Swift / SwiftUI ＋ [whisper.cpp](https://github.com/ggml-org/whisper.cpp)（Metal で GPU 処理）
- 対象：macOS 14 Sonoma 以降、Apple Silicon（M1 以降）
- 仕様書：[docs/SPEC.md](docs/SPEC.md)

> アプリ名は仮で「Transcribe」です。

## できること

- ドラッグ&ドロップ、または「ファイルを選択」でファイルを追加（複数可、キューで1本ずつ処理）
- 対応形式：mp4 / mov / m4v / m4a / mp3 / wav
- 言語の自動判定（判定結果を一覧に表示）。設定で言語を固定することもできます
- 進捗（%）と経過時間の表示、キャンセル
- 出力形式（複数同時に選択可）
  | 形式 | ファイル名 | 中身 |
  | --- | --- | --- |
  | 本文のみ | `元の名前.txt` | 区切りごとに改行したテキスト |
  | タイムスタンプ付き | `元の名前_timestamps.txt` | 各行の頭に `[00:12:34]` |
  | 字幕 | `元の名前.srt` | SRT 字幕 |
- 同名ファイルがあるときは `_2`, `_3` … を付けて上書きしません
- 完了時に通知と「Finderで表示」ボタン

## 開発状況

v0.1（開発中）。仕様書 6.2 の「実際の動画で速度と精度を測る」以降はまだです。

## ビルド方法

Xcode プロジェクトは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で `project.yml` から生成します（`.xcodeproj` はリポジトリに含めません）。

```sh
brew install xcodegen      # 初回のみ
./scripts/bootstrap.sh     # Transcribe.xcodeproj を生成
open Transcribe.xcodeproj
```

Xcode で `Transcribe` スキームを選んで ⌘R で実行します。
whisper.cpp は公式リリースの XCFramework を Swift Package（[`Packages/Whisper`](Packages/Whisper/Package.swift)）経由で取得するので、初回ビルド時に自動でダウンロードされます。

署名は「Sign to Run Locally」（アドホック署名）になっています。自分の Apple ID で署名したい場合は Xcode の Signing & Capabilities で Team を選んでください。

テストは ⌘U（`TranscribeTests`：txt / srt の整形と保存ファイル名のテスト）。

## 使い方

1. 初回起動時、モデル（large-v3-turbo、約1.6GB）のダウンロード案内が出るので「ダウンロード」を押す
2. 動画をウィンドウにドロップ
3. 終わったら「Finderで表示」で結果を開く

保存先の初期値は `~/Documents/Transcripts`（書類/Transcripts）です。設定（⌘,）で変更できます。

### モデル

| モデル | サイズ | 備考 |
| --- | --- | --- |
| large-v3-turbo | 約1.6GB | 既定。速さと精度のバランスが良い |
| large-v3 | 約3.1GB | 最も高精度だが遅い |
| small | 約490MB | 軽量・高速 |

モデルは `~/Library/Containers/<Bundle ID>/Data/Library/Application Support/Transcribe/models/` に保存されます（App Sandbox のためコンテナ内になります）。

## 配布について

ダウンロードした `.app` を開くと「開発元を確認できない」と表示される場合は、Finder でアプリを右クリック →「開く」を選ぶか、ソースからビルドしてください（公証していないため）。

## ライセンス

[MIT](LICENSE)

whisper.cpp も MIT ライセンスです。
