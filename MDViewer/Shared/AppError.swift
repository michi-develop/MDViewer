import Foundation

/// ファイル操作の内部エラーを、ユーザーが対応可能なメッセージへ変換するエラー型。
enum AppError: LocalizedError {
  case fileNotFound
  case accessDenied
  case unsupportedEncoding
  case readFailed
  case bookmarkFailed

  var errorDescription: String? {
    switch self {
    case .fileNotFound:
      "ファイルが見つかりません。移動または削除された可能性があります。"
    case .accessDenied:
      "このファイルを開く権限がありません。もう一度選択してください。"
    case .unsupportedEncoding:
      "UTF-8のMarkdownファイルを選択してください。"
    case .readFailed:
      "ファイルを読み込めませんでした。"
    case .bookmarkFailed:
      "ファイルの参照情報を復元できませんでした。"
    }
  }
}
