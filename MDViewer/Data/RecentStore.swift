import Foundation

/// 閲覧履歴の重複排除、並べ替え、件数制限、端末内保存を一元管理するストア。
@MainActor
final class RecentStore {
  static let shared = RecentStore()

  private let defaults: UserDefaults
  private let key: String
  private let limit: Int

  /// テストで保存領域と上限を差し替えられるよう、依存値を注入して初期化する。
  init(defaults: UserDefaults = .standard, key: String = "recentDocuments", limit: Int = 20) {
    self.defaults = defaults
    self.key = key
    self.limit = limit
  }

  /// 保存済み履歴を、最終閲覧日時が新しい順かつ上限件数内で返す。
  func load() -> [RecentDocument] {
    guard let data = defaults.data(forKey: key),
      let value = try? JSONDecoder().decode([RecentDocument].self, from: data)
    else {
      return []
    }
    return Array(value.sorted { $0.lastOpenedAt > $1.lastOpenedAt }.prefix(limit))
  }

  /// 同じファイルを複数の履歴項目にせず、最新の閲覧情報へ置き換える。
  func upsert(_ item: RecentDocument, url: URL) {
    var items = load()

    // UUIDは閲覧のたびに変わるため、Bookmarkが示す実体URLで同一ファイルを判定する。
    items.removeAll {
      (try? DocumentService.resolve($0.bookmarkData).standardizedFileURL) == url.standardizedFileURL
    }
    items.append(item)
    save(Array(items.sorted { $0.lastOpenedAt > $1.lastOpenedAt }.prefix(limit)))
  }

  /// 指定した履歴だけを削除し、ユーザーの元ファイルには触れない。
  func remove(_ id: UUID) {
    save(load().filter { $0.id != id })
  }

  /// エンコードできた履歴だけを保存し、壊れた中間データで既存値を上書きしない。
  private func save(_ items: [RecentDocument]) {
    if let data = try? JSONEncoder().encode(items) {
      defaults.set(data, forKey: key)
    }
  }
}
