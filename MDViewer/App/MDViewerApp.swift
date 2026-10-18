import SwiftUI

/// MDViewerのライフサイクルとルート画面を定義するアプリケーションエントリーポイント。
@main
struct MDViewerApp: App {
  var body: some Scene {
    WindowGroup {
      HomeView()
    }
  }
}
