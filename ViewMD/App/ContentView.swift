import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ViewMDCore

struct ContentView: View {
    @State private var document: MarkdownPreviewDocument?
    @State private var errorMessage: String?

    private let loader = MarkdownDocumentLoader()

    var body: some View {
        Group {
            if let document {
                MarkdownPreviewView(document: document)
            } else {
                VStack(spacing: 18) {
                    Text("ViewMD")
                        .font(.title)
                        .fontWeight(.semibold)
                    Button("Open Markdown File") {
                        openDocument()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .navigationTitle(document?.displayName ?? "ViewMD")
        .preferredColorScheme(nil)
        .onReceive(NotificationCenter.default.publisher(for: .viewMDOpenDocument)) { _ in
            openDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .viewMDOpenURLs)) { notification in
            guard let urls = notification.object as? [URL] else {
                return
            }
            openFirstDocument(from: urls)
            ExternalDocumentOpenRelay.clearPendingURLs()
        }
        .onAppear {
            openFirstDocument(from: ExternalDocumentOpenRelay.consumePendingURLs())
        }
        .onOpenURL { url in
            loadDocument(at: url)
        }
        .alert(
            "Could not open Markdown",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func openDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            "md",
            "markdown",
            "mdown",
            "mkd"
        ].compactMap { UTType(filenameExtension: $0) }

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        loadDocument(at: url)
    }

    private func openFirstDocument(from urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        loadDocument(at: url)
    }

    private func loadDocument(at url: URL) {
        do {
            document = try loader.load(from: url)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
