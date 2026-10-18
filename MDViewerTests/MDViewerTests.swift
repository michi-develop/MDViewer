import Foundation
import Testing

@testable import MDViewer

struct MarkdownParserTests {
  let parser = MarkdownParser()
  @Test func headingsAndParagraphs() {
    #expect(parser.parse("# Title\n\nHello") == [.heading(1, "Title"), .paragraph("Hello")])
  }
  @Test func lists() {
    #expect(
      parser.parse("- A\n- B\n\n1. One\n2. Two") == [
        .unorderedList(["A", "B"]), .orderedList(["One", "Two"]),
      ])
  }
  @Test func quoteDividerCode() {
    #expect(
      parser.parse("> Q\n\n---\n\n```swift\nlet x=1\n```") == [
        .quote("Q"), .divider, .code("swift", "let x=1"),
      ])
  }
  @Test func empty() { #expect(parser.parse("").isEmpty) }
}

@MainActor struct RecentStoreTests {
  @Test func newestFirstAndLimit() throws {
    let name = "test.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let store = RecentStore(defaults: defaults, limit: 2)
    for i in 0..<3 {
      let url = URL(fileURLWithPath: "/tmp/\(UUID()).md")
      let item = RecentDocument(
        fileName: "\(i)", bookmarkData: try url.bookmarkData(options: .minimalBookmark),
        lastOpenedAt: Date(timeIntervalSince1970: TimeInterval(i)))
      store.upsert(item, url: url)
    }
    #expect(store.load().map(\.fileName) == ["2", "1"])
  }
}
