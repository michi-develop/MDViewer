import Foundation

/// Markdown文書をSwiftUIで安全に描画できる表示単位へ抽象化したモデル。
enum MarkdownBlock: Equatable {
  case heading(Int, String)
  case paragraph(String)
  case unorderedList([String])
  case orderedList([String])
  case quote(String)
  case code(String?, String)
  case divider
}
