import SwiftUI

/// 読み込み済みMarkdownをブロックへ変換し、閲覧専用で表示する画面。
struct MarkdownViewerView: View {
  let document: ViewerDocument
  private let parser = MarkdownParser()

  var body: some View {
    let isEmpty = document.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

    Group {
      if isEmpty {
        ContentUnavailableView("このファイルは空です", systemImage: "doc")
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(Array(parser.parse(document.content).enumerated()), id: \.offset) { _, block in
              MarkdownBlockView(block: block)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
        }
      }
    }
    .navigationTitle(document.name)
    .navigationBarTitleDisplayMode(.inline)
  }
}
