import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ViewMDCore

struct ContentView: View {
    @State private var document: MarkdownPreviewDocument?
    @State private var errorMessage: String?
    @AppStorage(ExternalEditorPreferences.preferredBundleIdentifierKey)
    private var preferredEditorBundleIdentifier: String?

    private let loader = MarkdownDocumentLoader()
    private let editorLauncher = ExternalEditorLauncher()

    var body: some View {
        Group {
            if let document {
                MarkdownPreviewView(document: document)
            } else {
                VStack(spacing: 18) {
                    Image("ViewMDIcon")
                        .resizable()
                        .frame(width: 84, height: 84)
                        .accessibilityHidden(true)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let sourceURL = document?.sourceURL {
                    editorMenu(for: sourceURL)
                }
            }
        }
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

    @ViewBuilder
    private func editorMenu(for sourceURL: URL) -> some View {
        let installedEditors = editorLauncher.installedEditors()
        let preferredEditor = ExternalEditorCatalog.preferredEditor(
            bundleIdentifier: preferredEditorBundleIdentifier,
            installedEditors: installedEditors
        )

        Menu {
            ForEach(installedEditors) { editor in
                Button {
                    open(sourceURL, in: editor, rememberPreference: true)
                } label: {
                    if editor.bundleIdentifier == preferredEditor?.bundleIdentifier {
                        Label(editor.name, systemImage: "checkmark")
                    } else {
                        Text(editor.name)
                    }
                }
            }

            if installedEditors.isEmpty {
                Button("Open with Default App") {
                    openWithDefaultApplication(sourceURL)
                }
            }
        } label: {
            Label("Open in Editor", systemImage: "square.and.pencil")
        }
        .help("Open in Editor")
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

    private func open(
        _ sourceURL: URL,
        in editor: ExternalEditor,
        rememberPreference: Bool
    ) {
        if rememberPreference {
            preferredEditorBundleIdentifier = editor.bundleIdentifier
        }

        Task { @MainActor in
            do {
                try await editorLauncher.open(sourceURL, in: editor)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func openWithDefaultApplication(_ sourceURL: URL) {
        Task { @MainActor in
            do {
                try await editorLauncher.openWithDefaultApplication(sourceURL)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
