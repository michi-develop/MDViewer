# MDViewer

MDViewerは、iPhoneの「ファイル」アプリからMarkdownファイルを選択し、読みやすい形式で表示するシンプルなiOSアプリです。

閲覧に必要な機能だけに絞り、Swift・SwiftUIとApple純正APIのみで実装しています。アカウント登録、外部サーバー、広告、解析SDKは使用しません。

## 主な機能

- `.md` / `.markdown` ファイルの選択と表示
- 最近閲覧したファイルの履歴表示
- 履歴からの再表示とスワイプ削除
- 最大20件の履歴を最終閲覧日時順に保存
- 1 MBを超えるファイルを開く前の確認
- 空ファイル、権限失効、ファイル移動、非UTF-8ファイルのエラー表示
- Dynamic Type、ダークモード、VoiceOverを考慮したUI

## 対応するMarkdown記法

| 記法 | 表示 |
| --- | --- |
| `#` 〜 `######` | 見出し |
| 通常テキスト | 段落 |
| `**太字**`、`*斜体*` | インライン装飾 |
| `- item`、`1. item` | 箇条書き・番号付きリスト |
| `> quote` | 引用 |
| `` `code` `` | インラインコード |
| fenced code block | コードブロック |
| `---` | 区切り線 |
| `[label](URL)` | リンク |

表、画像、脚注、数式、Mermaid、埋め込みHTMLなどは、初期バージョンでは専用表示の対象外です。未対応の記法が含まれていても、可能な限り文字情報を残して表示します。

## 動作環境

- iOS 17.0以降
- iPhone
- Xcode 26.2以降
- Swift 6

## 使用技術

- SwiftUI
- Observation
- Uniform Type Identifiers
- Security-Scoped Resource / Bookmark
- UserDefaults + Codable
- Swift Testing

外部ライブラリ、WebView、JavaScript、Firebaseは使用していません。

## シミュレータで実行する

1. Xcodeで `MDViewer.xcodeproj` を開きます。
2. Schemeに `MDViewer` を選択します。
3. 実行先に任意のiPhoneシミュレータを選択します。
4. `Run`（`⌘R`）を実行します。
5. アプリ右上の `+` からMarkdownファイルを選択します。

## テスト

テストにはSwift Testingを使用しています。

## ファイルアクセスとプライバシー

MDViewerは、ユーザーがファイルピッカーで明示的に選択したファイルだけを読み込みます。

- ファイル本文を端末外へ送信しません。
- ファイル本文をアプリ内へ永続保存しません。
- 履歴にはファイル名、最終閲覧日時、再アクセス用Bookmarkだけを保存します。
- Security-Scoped Resourceへのアクセスは読み込み中だけ有効にします。
- 履歴を削除しても、元のMarkdownファイルは削除しません。

ファイルが移動・削除された場合や、ファイルプロバイダの権限が失効した場合は、ファイルピッカーから選択し直してください。

## アーキテクチャ

小規模なアプリとして理解しやすさを保ちながら、責務ごとにレイヤを分離しています。

```text
MDViewer/
├── App/
│   └── MDViewerApp.swift
├── Data/
│   ├── DocumentService.swift
│   └── RecentStore.swift
├── Domain/
│   ├── MarkdownParser.swift
│   └── Models/
│       ├── MarkdownBlock.swift
│       ├── RecentDocument.swift
│       └── ViewerDocument.swift
├── Presentation/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   └── Viewer/
│       ├── MarkdownBlockView.swift
│       └── MarkdownViewerView.swift
└── Shared/
    └── AppError.swift
```

### レイヤの責務

- `App`: アプリのエントリーポイント
- `Domain`: 表示モデルとMarkdown解析ルール
- `Data`: ファイルアクセスと履歴の永続化
- `Presentation`: SwiftUI画面と画面状態
- `Shared`: レイヤをまたいで利用する共通型

## ドキュメント

- [要件定義書](REQUIREMENTS.md)
- [仕様書](SPECIFICATION.md)
