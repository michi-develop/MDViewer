import Foundation

/// ファイル読み込み後に、画面表示と履歴保存へ渡す不変のデータ。
struct LoadedDocument {
  let url: URL
  let name: String
  let content: String
  let bookmark: Data
  let byteCount: Int
}

/// 外部ファイルへの権限管理、読み込み、永続的な参照の復元を担うサービス。
enum DocumentService {
  static let warningSize = 1_000_000

  /// 選択されたURLへ一時的にアクセスし、UTF-8文書とBookmarkを生成する。
  static func load(_ url: URL) throws -> LoadedDocument {
    let accessing = url.startAccessingSecurityScopedResource()

    // ファイルプロバイダのリソースを占有し続けないよう、成功・失敗を問わず権限を解放する。
    defer {
      if accessing {
        url.stopAccessingSecurityScopedResource()
      }
    }

    guard FileManager.default.fileExists(atPath: url.path) else {
      throw AppError.fileNotFound
    }

    do {
      let data = try Data(contentsOf: url, options: .mappedIfSafe)
      guard let text = String(data: data, encoding: .utf8) else {
        throw AppError.unsupportedEncoding
      }
      let bookmark = try url.bookmarkData(options: .minimalBookmark)
      return LoadedDocument(
        url: url,
        name: url.lastPathComponent,
        content: text,
        bookmark: bookmark,
        byteCount: data.count
      )
    } catch let error as AppError {
      throw error
    } catch CocoaError.fileReadNoPermission {
      throw AppError.accessDenied
    } catch {
      throw AppError.readFailed
    }
  }

  /// 保存済みBookmarkから、履歴項目が指す現在のファイルURLを復元する。
  static func resolve(_ data: Data) throws -> URL {
    var stale = false
    do {
      return try URL(
        resolvingBookmarkData: data,
        options: .withoutUI,
        bookmarkDataIsStale: &stale
      )
    } catch {
      throw AppError.bookmarkFailed
    }
  }
}
