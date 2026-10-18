# MDViewer 仕様書

## 1. システム概要

MDViewerは、iOS標準のファイルピッカーでユーザーが選択したMarkdownファイルを読み込み、SwiftUIで描画する閲覧専用アプリである。正常に閲覧したファイルの参照情報を端末内に保存し、初期画面から再度開けるようにする。

## 2. 技術仕様

- 言語: Swift 6系
- UIフレームワーク: SwiftUI
- 最低対応OS: iOS 17.0
- アプリ構成: SwiftUI App lifecycle
- 永続化: `UserDefaults` + `Codable`
- ファイル選択: SwiftUI `fileImporter`
- ファイル種別: `UniformTypeIdentifiers.UTType`
- 外部ファイル再アクセス: Security-Scoped Bookmark
- 非同期処理: Swift Concurrency（`async` / `await`）
- テスト: XCTest
- 外部依存: なし

## 3. 画面構成

### 3.1 履歴一覧画面（HomeView）

アプリ起動時に表示するルート画面。

#### 表示要素

- ナビゲーションタイトル: `MDViewer`
- ツールバーの追加ボタン
  - アイコン: `plus`
  - Accessibility Label: `Markdownファイルを開く`
- 閲覧履歴リスト
  - ファイル名
  - 最終閲覧日時
  - 再アクセス不能時の警告表示（状態判明後）
- 空状態
  - メッセージ: `Markdownファイルを開いてみましょう`
  - ボタン: `ファイルを開く`

#### 操作

- 追加ボタンまたは空状態のボタンを押すとファイルピッカーを表示する。
- 履歴項目をタップするとファイルを読み込み、Viewer画面へ遷移する。
- 履歴項目を左スワイプすると `履歴から削除` を表示する。
- 削除操作では履歴データだけを削除し、元ファイルには変更を加えない。

### 3.2 Viewer画面（MarkdownViewerView）

#### 表示要素

- ナビゲーションタイトル: ファイル名（拡張子を含む）
- Markdown本文
- 読み込み中: `ProgressView`
- 空ファイル: `このファイルは空です`
- 読み込み失敗: エラー内容と戻る操作

#### 操作

- 本文を縦スクロールできる。
- URLリンクをタップするとiOS標準動作で開く。
- 戻る操作で履歴一覧へ戻る。
- 編集操作は提供しない。

### 3.3 エラー表示

復旧可能なエラーはAlertで通知する。

| 状況 | 表示文言 | 操作 |
| --- | --- | --- |
| ファイルが見つからない | `ファイルが見つかりません。移動または削除された可能性があります。` | `OK` |
| アクセス権失効 | `このファイルを開く権限がありません。ファイルをもう一度選択してください。` | `ファイルを選択` / `キャンセル` |
| 非UTF-8 | `このファイルの文字コードには対応していません。UTF-8のファイルを選択してください。` | `OK` |
| 読み込み失敗 | `ファイルを読み込めませんでした。` | `再試行` / `戻る` |
| サイズ超過警告 | `ファイルが大きいため、表示に時間がかかる可能性があります。` | `表示する` / `キャンセル` |

## 4. 画面遷移

```text
アプリ起動
  └─ 履歴一覧
      ├─ ファイルを開く → ファイルピッカー
      │                    ├─ 選択成功 → Viewer
      │                    └─ キャンセル → 履歴一覧
      └─ 履歴をタップ
           ├─ 読み込み成功 → Viewer
           └─ 読み込み失敗 → エラー表示
```

## 5. ファイル選択仕様

### 5.1 許可するファイル形式

`UTType(filenameExtension:)` で次の拡張子に対応する型を生成し、`fileImporter` の `allowedContentTypes` に指定する。

- `md`
- `markdown`

一度に選択できるファイルは1件とする。

### 5.2 読み込み処理

1. 選択URLに対して `startAccessingSecurityScopedResource()` を呼び出す。
2. `Data(contentsOf:)` 相当の処理をバックグラウンドで行う。
3. UTF-8文字列へ変換する。
4. Markdownを解析して表示モデルを生成する。
5. Security-Scoped Bookmark Dataを生成する。
6. 履歴を更新する。
7. `stopAccessingSecurityScopedResource()` を必ず呼び出す。

ファイル本文はキャッシュまたは永続保存しない。Viewerを開くたびに原本を読み直す。

### 5.3 サイズの扱い

- 1 MB以下: 通常どおり読み込む。
- 1 MB超: 警告後、ユーザーが許可した場合のみ読み込む。
- メモリ確保やデコードに失敗した場合: 読み込みエラーとして処理する。

## 6. 履歴仕様

### 6.1 データモデル

```swift
struct RecentDocument: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String
    var bookmarkData: Data
    var lastOpenedAt: Date
}
```

### 6.2 保存仕様

- `RecentDocument` の配列をJSONへエンコードし、`UserDefaults`へ保存する。
- UserDefaultsキー: `recentDocuments`
- 表示順: `lastOpenedAt` の降順
- 最大保持件数: 20件
- 21件目を追加した場合、最終閲覧日時が最も古い項目を履歴から削除する。
- 同一性は、Bookmarkから解決した標準化URLを基準に判定する。
- Bookmarkがstaleの場合は、新しいBookmarkを生成して保存し直す。

### 6.3 履歴更新タイミング

ファイルの読み込みとUTF-8変換が成功し、Viewerへ表示可能になった時点で更新する。読み込みに失敗したファイルは新規履歴へ追加しない。

## 7. Markdown表示仕様

### 7.1 描画方式

WebViewやJavaScriptは使用せず、Markdownをブロック単位に解析し、SwiftUIの標準Viewで描画する。

```text
Markdown文字列
  → MarkdownParser
  → [MarkdownBlock]
  → MarkdownContentView
  → SwiftUI標準View
```

インライン装飾はFoundationの `AttributedString` Markdown初期化機能を利用できる範囲で使用し、ブロック要素はアプリ側で判定する。

### 7.2 対応記法

| Markdown | 表示 |
| --- | --- |
| `#`〜`######` | レベルに応じた太字・文字サイズの見出し |
| 通常文 | 段落として表示 |
| `**bold**` / `__bold__` | 太字 |
| `*italic*` / `_italic_` | 斜体 |
| `~~text~~` | 取り消し線 |
| `-` / `*` / `+` | 箇条書き |
| `1.` | 番号付きリスト |
| `>` | 左罫線付き引用 |
| `` `code` `` | 等幅フォントのインラインコード |
| fenced code block | 等幅フォント、背景色付きコードブロック |
| `---` 等 | 区切り線 |
| `[label](URL)` | タップ可能なリンク |

### 7.3 未対応記法

表、画像、タスクリスト、脚注、数式、Mermaid、埋め込みHTMLなどは専用描画を行わない。可能な限り元の文字情報を欠落させず、通常テキストまたは簡易表示にフォールバックする。

HTMLは実行・解釈しない。

## 8. アーキテクチャ

シンプルなMVVM構成とする。

```text
MDViewerApp
├─ Features
│  ├─ Home
│  │  ├─ HomeView
│  │  └─ HomeViewModel
│  └─ Viewer
│     ├─ MarkdownViewerView
│     └─ MarkdownViewerViewModel
├─ Models
│  ├─ RecentDocument
│  └─ MarkdownBlock
├─ Services
│  ├─ DocumentService
│  ├─ RecentDocumentStore
│  └─ MarkdownParser
└─ Shared
   └─ AppError
```

### 責務

- `HomeView`: 履歴一覧とファイルピッカーの表示
- `HomeViewModel`: 履歴取得・選択・削除・画面状態管理
- `MarkdownViewerView`: Markdownブロックの描画
- `MarkdownViewerViewModel`: 読み込み状態と表示モデル管理
- `DocumentService`: Security-Scoped URL、Bookmark、ファイル読み込み
- `RecentDocumentStore`: 履歴の永続化と並べ替え・上限管理
- `MarkdownParser`: Markdown文字列から表示ブロックへの変換

## 9. 状態管理

### HomeViewState

- `loading`: 保存済み履歴を読み込み中
- `empty`: 履歴0件
- `loaded([RecentDocument])`: 履歴表示中
- `error(AppError)`: 履歴読み込み失敗

### ViewerState

- `idle`
- `loading`
- `loaded([MarkdownBlock])`
- `empty`
- `failed(AppError)`

UIを更新するViewModelはMain Actor上で動作させ、ファイルI/Oと解析はUIを停止させない形で実行する。

## 10. アクセシビリティ・表示

- システム標準色を使用し、ライト・ダークモードに自動対応する。
- 固定フォントサイズを避け、Dynamic Typeに対応する。
- コードブロックは長い行を横スクロール可能にする。
- VoiceOverの読み上げ順を画面上の表示順と一致させる。
- アイコンだけのボタンにはAccessibility Labelを設定する。
- 文字選択は可能とする。

## 11. エラー設計

```swift
enum AppError: LocalizedError {
    case fileNotFound
    case accessDenied
    case unsupportedEncoding
    case readFailed
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    case fileTooLarge
}
```

内部エラーの詳細はユーザーへ直接露出せず、復旧方法が分かる日本語メッセージへ変換する。デバッグビルドでは開発用ログを出力してよいが、ファイル本文はログに含めない。

## 12. テスト仕様

### 12.1 単体テスト

- 履歴が最終閲覧日時の降順になる。
- 同一ファイルが重複登録されない。
- 履歴が20件を超えない。
- 履歴削除で元ファイルを操作しない。
- Bookmarkの生成・解決・stale更新を処理できる。
- UTF-8 BOMあり・なしを読み込める。
- 空文字列を空状態として扱う。
- 各対応Markdown記法を期待する `MarkdownBlock` へ変換できる。
- 不正または未対応記法でも解析処理がクラッシュしない。

### 12.2 UIテスト

- 履歴0件の空状態が表示される。
- ファイル選択ボタンからファイルピッカーを開始できる。
- 履歴タップでViewerへ遷移する。
- 履歴をスワイプ削除できる。
- 読み込み中・空ファイル・エラー状態が表示される。
- Dynamic Type最大付近でも主要操作が可能である。

### 12.3 受入テスト用サンプル

- 基本記法をすべて含むファイル
- 空ファイル
- 日本語・絵文字を含むUTF-8ファイル
- 1 MB超のファイル
- UTF-8以外のファイル
- 登録後に移動または削除されたファイル

## 13. 実装対象外と将来拡張候補

初期実装では要件定義書の対象外項目を実装しない。将来的な候補として、表・画像・タスクリスト対応、共有、全文検索、お気に入りを検討できるが、初期アーキテクチャに過度な抽象化は持ち込まない。

