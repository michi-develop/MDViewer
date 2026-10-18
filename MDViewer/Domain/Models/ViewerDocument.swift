import Foundation

/// Viewer画面への遷移と表示に必要な、読み込み済み文書のスナップショット。
struct ViewerDocument: Identifiable, Hashable {
  let id = UUID()
  let name: String
  let content: String
}
