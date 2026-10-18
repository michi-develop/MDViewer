import Observation
import SwiftUI
import UniformTypeIdentifiers

@main
struct MDViewerApp: App {
  var body: some Scene { WindowGroup { HomeView() } }
}

struct RecentDocument: Identifiable, Codable, Equatable {
  let id: UUID
  var fileName: String
  var bookmarkData: Data
  var lastOpenedAt: Date

  init(id: UUID = UUID(), fileName: String, bookmarkData: Data, lastOpenedAt: Date = .now) {
    self.id = id
    self.fileName = fileName
    self.bookmarkData = bookmarkData
    self.lastOpenedAt = lastOpenedAt
  }
}

enum MarkdownBlock: Equatable {
  case heading(Int, String)
  case paragraph(String)
  case unorderedList([String])
  case orderedList([String])
  case quote(String)
  case code(String?, String)
  case divider
}

enum AppError: LocalizedError {
  case fileNotFound, accessDenied, unsupportedEncoding, readFailed, bookmarkFailed
  var errorDescription: String? {
    switch self {
    case .fileNotFound: "ファイルが見つかりません。移動または削除された可能性があります。"
    case .accessDenied: "このファイルを開く権限がありません。もう一度選択してください。"
    case .unsupportedEncoding: "UTF-8のMarkdownファイルを選択してください。"
    case .readFailed: "ファイルを読み込めませんでした。"
    case .bookmarkFailed: "ファイルの参照情報を復元できませんでした。"
    }
  }
}

struct LoadedDocument {
  let url: URL, name: String, content: String
  let bookmark: Data
  let byteCount: Int
}

enum DocumentService {
  static let warningSize = 1_000_000
  static func load(_ url: URL) throws -> LoadedDocument {
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    guard FileManager.default.fileExists(atPath: url.path) else { throw AppError.fileNotFound }
    do {
      let data = try Data(contentsOf: url, options: .mappedIfSafe)
      guard let text = String(data: data, encoding: .utf8) else {
        throw AppError.unsupportedEncoding
      }
      let bookmark = try url.bookmarkData(options: .minimalBookmark)
      return LoadedDocument(
        url: url, name: url.lastPathComponent, content: text,
        bookmark: bookmark, byteCount: data.count)
    } catch let error as AppError { throw error } catch CocoaError.fileReadNoPermission {
      throw AppError.accessDenied
    } catch { throw AppError.readFailed }
  }

  static func resolve(_ data: Data) throws -> URL {
    var stale = false
    do {
      return try URL(
        resolvingBookmarkData: data, options: .withoutUI,
        bookmarkDataIsStale: &stale)
    } catch { throw AppError.bookmarkFailed }
  }
}

@MainActor
final class RecentStore {
  static let shared = RecentStore()
  private let defaults: UserDefaults, key: String, limit: Int
  init(defaults: UserDefaults = .standard, key: String = "recentDocuments", limit: Int = 20) {
    self.defaults = defaults
    self.key = key
    self.limit = limit
  }
  func load() -> [RecentDocument] {
    guard let data = defaults.data(forKey: key),
      let value = try? JSONDecoder().decode([RecentDocument].self, from: data)
    else { return [] }
    return Array(value.sorted { $0.lastOpenedAt > $1.lastOpenedAt }.prefix(limit))
  }
  func upsert(_ item: RecentDocument, url: URL) {
    var items = load()
    items.removeAll {
      (try? DocumentService.resolve($0.bookmarkData).standardizedFileURL) == url.standardizedFileURL
    }
    items.append(item)
    save(Array(items.sorted { $0.lastOpenedAt > $1.lastOpenedAt }.prefix(limit)))
  }
  func remove(_ id: UUID) { save(load().filter { $0.id != id }) }
  private func save(_ items: [RecentDocument]) {
    if let data = try? JSONEncoder().encode(items) { defaults.set(data, forKey: key) }
  }
}

struct MarkdownParser {
  func parse(_ source: String) -> [MarkdownBlock] {
    let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
    var result: [MarkdownBlock] = []
    var text: [String] = []
    var list: [String] = []
    var numbers: [String] = []
    var quotes: [String] = []
    var code: [String] = []
    var language: String?
    var inCode = false
    func flush() {
      if !text.isEmpty {
        result.append(.paragraph(text.joined(separator: " ")))
        text = []
      }
      if !list.isEmpty {
        result.append(.unorderedList(list))
        list = []
      }
      if !numbers.isEmpty {
        result.append(.orderedList(numbers))
        numbers = []
      }
      if !quotes.isEmpty {
        result.append(.quote(quotes.joined(separator: "\n")))
        quotes = []
      }
    }
    for raw in lines {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.hasPrefix("```") || line.hasPrefix("~~~") {
        if inCode {
          result.append(.code(language, code.joined(separator: "\n")))
          code = []
          language = nil
        } else {
          flush()
          let value = String(line.dropFirst(3))
          language = value.isEmpty ? nil : value
        }
        inCode.toggle()
        continue
      }
      if inCode {
        code.append(raw)
        continue
      }
      if line.isEmpty {
        flush()
        continue
      }
      let hashes = line.prefix { $0 == "#" }.count
      if (1...6).contains(hashes), line.dropFirst(hashes).first == " " {
        flush()
        result.append(.heading(hashes, String(line.dropFirst(hashes + 1))))
        continue
      }
      let compact = line.filter { !$0.isWhitespace }
      if compact.count >= 3, let c = compact.first, "-*_".contains(c),
        compact.allSatisfy({ $0 == c })
      {
        flush()
        result.append(.divider)
        continue
      }
      if ["- ", "* ", "+ "].contains(where: line.hasPrefix) {
        if !text.isEmpty || !numbers.isEmpty || !quotes.isEmpty { flush() }
        list.append(String(line.dropFirst(2)))
        continue
      }
      if let dot = line.firstIndex(of: "."), dot != line.startIndex,
        line[..<dot].allSatisfy(\.isNumber), line[line.index(after: dot)...].first == " "
      {
        if !text.isEmpty || !list.isEmpty || !quotes.isEmpty { flush() }
        numbers.append(String(line[line.index(after: dot)...].dropFirst()))
        continue
      }
      if line.hasPrefix(">") {
        if !text.isEmpty || !list.isEmpty || !numbers.isEmpty { flush() }
        quotes.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
        continue
      }
      if !list.isEmpty || !numbers.isEmpty || !quotes.isEmpty { flush() }
      text.append(line)
    }
    if inCode { result.append(.code(language, code.joined(separator: "\n"))) } else { flush() }
    return result
  }
}

struct ViewerDocument: Identifiable, Hashable {
  let id = UUID(), name: String, content: String
}

@MainActor @Observable
final class HomeViewModel {
  var documents: [RecentDocument]
  var selected: ViewerDocument?
  var error: AppError?
  var pendingLarge: LoadedDocument?
  private let store: RecentStore
  init(store: RecentStore = .shared) {
    self.store = store
    documents = store.load()
  }
  func open(_ url: URL) {
    do {
      let loaded = try DocumentService.load(url)
      loaded.byteCount > DocumentService.warningSize ? (pendingLarge = loaded) : show(loaded)
    } catch let value as AppError { error = value } catch { error = .readFailed }
  }
  func open(_ recent: RecentDocument) {
    do { open(try DocumentService.resolve(recent.bookmarkData)) } catch { error = .bookmarkFailed }
  }
  func showPending() {
    if let pendingLarge {
      self.pendingLarge = nil
      show(pendingLarge)
    }
  }
  func remove(_ offsets: IndexSet) {
    for i in offsets { store.remove(documents[i].id) }
    documents = store.load()
  }
  private func show(_ loaded: LoadedDocument) {
    store.upsert(
      RecentDocument(fileName: loaded.name, bookmarkData: loaded.bookmark), url: loaded.url)
    documents = store.load()
    selected = ViewerDocument(name: loaded.name, content: loaded.content)
  }
}

struct HomeView: View {
  @State private var model = HomeViewModel()
  @State private var importer = false
  var body: some View {
    @Bindable var model = model
    NavigationStack {
      Group {
        if model.documents.isEmpty {
          ContentUnavailableView(
            "履歴はありません", systemImage: "doc.richtext",
            description: Text("Markdownファイルを開いてみましょう"),
            actions: { Button("ファイルを開く") { importer = true }.buttonStyle(.borderedProminent) })
        } else {
          List {
            ForEach(model.documents) { item in
              Button {
                model.open(item)
              } label: {
                HStack {
                  Image(systemName: "doc.text").foregroundStyle(.tint)
                  VStack(alignment: .leading) {
                    Text(item.fileName)
                    Text(item.lastOpenedAt, format: .dateTime.year().month().day().hour().minute())
                      .font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
              }.buttonStyle(.plain)
            }.onDelete(perform: model.remove)
          }
        }
      }.navigationTitle("MDViewer").toolbar {
        Button {
          importer = true
        } label: {
          Image(systemName: "plus")
        }.accessibilityLabel("Markdownファイルを開く")
      }
      .navigationDestination(item: $model.selected) { MarkdownViewer(document: $0) }
      .fileImporter(
        isPresented: $importer,
        allowedContentTypes: ["md", "markdown"].compactMap(UTType.init(filenameExtension:))
      ) { result in
        if case .success(let url) = result {
          model.open(url)
        } else if case .failure = result {
          model.error = .readFailed
        }
      }
      .alert(
        "ファイルを開けません",
        isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(model.error?.localizedDescription ?? "不明なエラーです。")
      }
      .alert(
        "大きなファイル",
        isPresented: Binding(
          get: { model.pendingLarge != nil }, set: { if !$0 { model.pendingLarge = nil } })
      ) {
        Button("表示する") { model.showPending() }
        Button("キャンセル", role: .cancel) {}
      } message: {
        Text("ファイルが大きいため、表示に時間がかかる可能性があります。")
      }
    }
  }
}

struct MarkdownViewer: View {
  let document: ViewerDocument
  private let parser = MarkdownParser()
  var body: some View {
    let empty = document.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    Group {
      if empty {
        ContentUnavailableView("このファイルは空です", systemImage: "doc")
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(Array(parser.parse(document.content).enumerated()), id: \.offset) { _, block in
              BlockView(block: block)
            }
          }.frame(maxWidth: .infinity, alignment: .leading).padding()
        }
      }
    }.navigationTitle(document.name).navigationBarTitleDisplayMode(.inline)
  }
}

struct BlockView: View {
  let block: MarkdownBlock
  var body: some View {
    switch block {
    case .heading(let n, let s):
      inline(s).font(n == 1 ? .largeTitle : n == 2 ? .title : n == 3 ? .title2 : .headline).bold()
    case .paragraph(let s): inline(s)
    case .unorderedList(let items):
      VStack(alignment: .leading, spacing: 8) {
        ForEach(items.indices, id: \.self) { i in
          HStack(alignment: .firstTextBaseline) {
            Text("•")
            inline(items[i])
          }
        }
      }
    case .orderedList(let items):
      VStack(alignment: .leading, spacing: 8) {
        ForEach(items.indices, id: \.self) { i in
          HStack(alignment: .firstTextBaseline) {
            Text("\(i+1).")
            inline(items[i])
          }
        }
      }
    case .quote(let s):
      HStack {
        Rectangle().fill(.secondary).frame(width: 4)
        inline(s).italic().foregroundStyle(.secondary)
      }
    case .code(let lang, let s):
      VStack(alignment: .leading) {
        if let lang { Text(lang).font(.caption).foregroundStyle(.secondary) }
        ScrollView(.horizontal) {
          Text(s).font(.system(.body, design: .monospaced)).fixedSize(
            horizontal: true, vertical: false)
        }
      }.padding().background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    case .divider: Divider()
    }
  }
  private func inline(_ value: String) -> Text {
    (try? Text(
      AttributedString(
        markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))))
      ?? Text(value)
  }
}
