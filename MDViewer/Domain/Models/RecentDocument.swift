import Foundation

/// 一度開いた文書を、次回起動後にも再表示するための履歴情報。
struct RecentDocument: Identifiable, Codable, Equatable {
  let id: UUID
  var fileName: String
  var bookmarkData: Data
  var lastOpenedAt: Date

  /// ファイル本文を保持せず、表示用メタデータと再アクセス情報だけで履歴を生成する。
  init(id: UUID = UUID(), fileName: String, bookmarkData: Data, lastOpenedAt: Date = .now) {
    self.id = id
    self.fileName = fileName
    self.bookmarkData = bookmarkData
    self.lastOpenedAt = lastOpenedAt
  }
}
