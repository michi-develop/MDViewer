import SwiftUI

/// MarkdownBlockごとの意味を、対応するSwiftUI標準Viewへ変換するView。
struct MarkdownBlockView: View {
  let block: MarkdownBlock

  var body: some View {
    switch block {
    case .heading(let level, let content):
      inlineText(content)
        .font(headingFont(for: level))
        .bold()

    case .paragraph(let content):
      inlineText(content)

    case .unorderedList(let items):
      VStack(alignment: .leading, spacing: 8) {
        ForEach(items.indices, id: \.self) { index in
          HStack(alignment: .firstTextBaseline) {
            Text("•")
            inlineText(items[index])
          }
        }
      }

    case .orderedList(let items):
      VStack(alignment: .leading, spacing: 8) {
        ForEach(items.indices, id: \.self) { index in
          HStack(alignment: .firstTextBaseline) {
            Text("\(index + 1).")
            inlineText(items[index])
          }
        }
      }

    case .quote(let content):
      HStack {
        Rectangle()
          .fill(.secondary)
          .frame(width: 4)
        inlineText(content)
          .italic()
          .foregroundStyle(.secondary)
      }

    case .code(let language, let content):
      VStack(alignment: .leading) {
        if let language {
          Text(language)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        ScrollView(.horizontal) {
          Text(content)
            .font(.system(.body, design: .monospaced))
            .fixedSize(horizontal: true, vertical: false)
        }
      }
      .padding()
      .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

    case .divider:
      Divider()
    }
  }

  /// FoundationのインラインMarkdown解釈を使い、独自実装による記法差異を最小化する。
  private func inlineText(_ value: String) -> Text {
    let attributedString = try? AttributedString(
      markdown: value,
      options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )
    return attributedString.map(Text.init) ?? Text(value)
  }

  /// 見出し階層をDynamic Type対応のシステムフォントへ対応付ける。
  private func headingFont(for level: Int) -> Font {
    switch level {
    case 1: .largeTitle
    case 2: .title
    case 3: .title2
    default: .headline
    }
  }
}
