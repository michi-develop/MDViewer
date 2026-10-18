import SwiftUI
import UniformTypeIdentifiers

/// 閲覧履歴とMarkdownファイル選択の入口を提供する初期画面。
struct HomeView: View {
  @State private var viewModel = HomeViewModel()
  @State private var isImporterPresented = false

  var body: some View {
    @Bindable var viewModel = viewModel

    NavigationStack {
      Group {
        if viewModel.documents.isEmpty {
          EmptyHistoryView {
            isImporterPresented = true
          }
        } else {
          RecentDocumentList(viewModel: viewModel)
        }
      }
      .navigationTitle("MDViewer")
      .toolbar {
        Button {
          isImporterPresented = true
        } label: {
          Image(systemName: "plus")
        }
        .accessibilityLabel("Markdownファイルを開く")
      }
      .navigationDestination(item: $viewModel.selectedDocument) {
        MarkdownViewerView(document: $0)
      }
      .fileImporter(
        isPresented: $isImporterPresented,
        allowedContentTypes: ["md", "markdown"].compactMap { UTType(filenameExtension: $0) }
      ) { result in
        switch result {
        case .success(let url):
          viewModel.open(url)
        case .failure:
          viewModel.error = .readFailed
        }
      }
      .alert(
        "ファイルを開けません",
        isPresented: Binding(
          get: { viewModel.error != nil },
          set: { if !$0 { viewModel.error = nil } }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(viewModel.error?.localizedDescription ?? "不明なエラーです。")
      }
      .alert(
        "大きなファイル",
        isPresented: Binding(
          get: { viewModel.pendingLargeDocument != nil },
          set: { if !$0 { viewModel.pendingLargeDocument = nil } }
        )
      ) {
        Button("表示する") { viewModel.showPendingDocument() }
        Button("キャンセル", role: .cancel) {}
      } message: {
        Text("ファイルが大きいため、表示に時間がかかる可能性があります。")
      }
    }
  }
}

/// 履歴がない理由と次に行う操作を一画面で伝える空状態View。
private struct EmptyHistoryView: View {
  let openFile: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("履歴はありません", systemImage: "doc.richtext")
    } description: {
      Text("Markdownファイルを開いてみましょう")
    } actions: {
      Button("ファイルを開く", action: openFile)
        .buttonStyle(.borderedProminent)
    }
  }
}

/// 保存済み文書を最終閲覧順で表示し、再表示と履歴削除を提供するList。
private struct RecentDocumentList: View {
  let viewModel: HomeViewModel

  var body: some View {
    List {
      ForEach(viewModel.documents) { document in
        Button {
          viewModel.open(document)
        } label: {
          RecentDocumentRow(document: document)
        }
        .buttonStyle(.plain)
      }
      .onDelete(perform: viewModel.remove)
    }
  }
}

/// ファイル名と最終閲覧日時を読みやすくまとめる履歴行View。
private struct RecentDocumentRow: View {
  let document: RecentDocument

  var body: some View {
    HStack {
      Image(systemName: "doc.text")
        .foregroundStyle(.tint)
      VStack(alignment: .leading) {
        Text(document.fileName)
        Text(document.lastOpenedAt, format: .dateTime.year().month().day().hour().minute())
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .foregroundStyle(.tertiary)
    }
  }
}
