import Foundation

/// Markdown文字列を、標準SwiftUI Viewで描画可能なブロック列へ変換するパーサー。
struct MarkdownParser {
  /// 対応するブロック記法を抽出し、未対応の内容は段落として残す。
  func parse(_ source: String) -> [MarkdownBlock] {
    let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
    var result: [MarkdownBlock] = []
    var text: [String] = []
    var unorderedItems: [String] = []
    var orderedItems: [String] = []
    var quotes: [String] = []
    var code: [String] = []
    var language: String?
    var isInsideCodeBlock = false

    // 種類が切り替わる境界でまとめて確定することで、連続行を一つのブロックとして保つ。
    func flushPendingBlocks() {
      if !text.isEmpty {
        result.append(.paragraph(text.joined(separator: " ")))
        text = []
      }
      if !unorderedItems.isEmpty {
        result.append(.unorderedList(unorderedItems))
        unorderedItems = []
      }
      if !orderedItems.isEmpty {
        result.append(.orderedList(orderedItems))
        orderedItems = []
      }
      if !quotes.isEmpty {
        result.append(.quote(quotes.joined(separator: "\n")))
        quotes = []
      }
    }

    for rawLine in lines {
      let line = rawLine.trimmingCharacters(in: .whitespaces)

      if line.hasPrefix("```") || line.hasPrefix("~~~") {
        if isInsideCodeBlock {
          result.append(.code(language, code.joined(separator: "\n")))
          code = []
          language = nil
        } else {
          flushPendingBlocks()
          let value = String(line.dropFirst(3))
          language = value.isEmpty ? nil : value
        }
        isInsideCodeBlock.toggle()
        continue
      }

      if isInsideCodeBlock {
        // コードではインデントも意味を持つため、trim前の行を保存する。
        code.append(rawLine)
        continue
      }
      if line.isEmpty {
        flushPendingBlocks()
        continue
      }

      let headingLevel = line.prefix { $0 == "#" }.count
      if (1...6).contains(headingLevel), line.dropFirst(headingLevel).first == " " {
        flushPendingBlocks()
        result.append(.heading(headingLevel, String(line.dropFirst(headingLevel + 1))))
        continue
      }

      let compactLine = line.filter { !$0.isWhitespace }
      if compactLine.count >= 3,
        let marker = compactLine.first,
        "-*_".contains(marker),
        compactLine.allSatisfy({ $0 == marker })
      {
        flushPendingBlocks()
        result.append(.divider)
        continue
      }

      if ["- ", "* ", "+ "].contains(where: line.hasPrefix) {
        if !text.isEmpty || !orderedItems.isEmpty || !quotes.isEmpty { flushPendingBlocks() }
        unorderedItems.append(String(line.dropFirst(2)))
        continue
      }

      if let dot = line.firstIndex(of: "."),
        dot != line.startIndex,
        line[..<dot].allSatisfy(\.isNumber),
        line[line.index(after: dot)...].first == " "
      {
        if !text.isEmpty || !unorderedItems.isEmpty || !quotes.isEmpty { flushPendingBlocks() }
        orderedItems.append(String(line[line.index(after: dot)...].dropFirst()))
        continue
      }

      if line.hasPrefix(">") {
        if !text.isEmpty || !unorderedItems.isEmpty || !orderedItems.isEmpty {
          flushPendingBlocks()
        }
        quotes.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
        continue
      }

      if !unorderedItems.isEmpty || !orderedItems.isEmpty || !quotes.isEmpty {
        flushPendingBlocks()
      }
      text.append(line)
    }

    // 閉じ忘れたコードフェンスでも内容を失わず表示する。
    if isInsideCodeBlock {
      result.append(.code(language, code.joined(separator: "\n")))
    } else {
      flushPendingBlocks()
    }
    return result
  }
}
