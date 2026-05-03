import Cocoa
import Quartz
import SwiftUI
import ViewMDCore

final class PreviewViewController: NSViewController, QLPreviewingController {
    private let loader = MarkdownDocumentLoader()
    private var hostingView: NSHostingView<MarkdownPreviewView>?

    override func loadView() {
        let view = NSHostingView(
            rootView: MarkdownPreviewView(
                document: MarkdownPreviewDocument(blocks: [])
            )
        )
        hostingView = view
        self.view = view
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let document = try loader.load(from: url)
        await MainActor.run {
            hostingView?.rootView = MarkdownPreviewView(document: document)
        }
    }
}
