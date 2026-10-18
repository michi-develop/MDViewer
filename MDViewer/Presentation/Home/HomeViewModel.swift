import Foundation
import Observation

/// 履歴一覧とファイル選択後の画面遷移状態を管理するHome画面のViewModel。
@MainActor
@Observable
final class HomeViewModel {
  var documents: [RecentDocument]
  var selectedDocument: ViewerDocument?
  var error: AppError?
  var pendingLargeDocument: LoadedDocument?

  private let store: RecentStore

  /// 履歴ストアを差し替え可能にし、UIから永続化方法を切り離す。
  init(store: RecentStore = .shared) {
    self.store = store
    documents = store.load()
  }

  /// 選択されたURLを読み込み、サイズに応じて確認またはViewer遷移へ進める。
  func open(_ url: URL) {
    do {
      let loadedDocument = try DocumentService.load(url)
      if loadedDocument.byteCount > DocumentService.warningSize {
        pendingLargeDocument = loadedDocument
      } else {
        show(loadedDocument)
      }
    } catch let appError as AppError {
      error = appError
    } catch {
      self.error = .readFailed
    }
  }

  /// 履歴のBookmarkを現在のURLへ解決してから、通常の読み込み経路へ合流させる。
  func open(_ recentDocument: RecentDocument) {
    do {
      open(try DocumentService.resolve(recentDocument.bookmarkData))
    } catch {
      self.error = .bookmarkFailed
    }
  }

  /// ユーザーの明示的な了承後に、大容量文書をViewerへ渡す。
  func showPendingDocument() {
    guard let pendingLargeDocument else { return }
    self.pendingLargeDocument = nil
    show(pendingLargeDocument)
  }

  /// リストの指定位置にある履歴だけを削除し、表示内容を保存結果と同期する。
  func remove(_ offsets: IndexSet) {
    for index in offsets {
      store.remove(documents[index].id)
    }
    documents = store.load()
  }

  /// 読み込み成功後だけ履歴へ追加し、壊れたファイルが一覧に残ることを防ぐ。
  private func show(_ loadedDocument: LoadedDocument) {
    store.upsert(
      RecentDocument(fileName: loadedDocument.name, bookmarkData: loadedDocument.bookmark),
      url: loadedDocument.url
    )
    documents = store.load()
    selectedDocument = ViewerDocument(name: loadedDocument.name, content: loadedDocument.content)
  }
}
