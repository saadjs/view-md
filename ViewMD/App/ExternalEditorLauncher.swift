import AppKit
import Foundation
import ViewMDCore

struct ExternalEditorLaunchFailure: LocalizedError {
    let fileURL: URL
    let editorName: String

    var errorDescription: String? {
        "Could not open \(fileURL.lastPathComponent) in \(editorName)."
    }
}

@MainActor
struct ExternalEditorLauncher {
    var workspace: NSWorkspace = .shared

    func installedEditors() -> [ExternalEditor] {
        ExternalEditorCatalog.installedEditors { bundleIdentifier in
            workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
        }
    }

    func open(_ fileURL: URL, in editor: ExternalEditor) async throws {
        guard let applicationURL = workspace.urlForApplication(withBundleIdentifier: editor.bundleIdentifier) else {
            throw ExternalEditorLaunchFailure(fileURL: fileURL, editorName: editor.name)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        do {
            try await workspace.open(
                [fileURL],
                withApplicationAt: applicationURL,
                configuration: configuration
            )
        } catch {
            throw ExternalEditorLaunchFailure(fileURL: fileURL, editorName: editor.name)
        }
    }

    func openWithDefaultApplication(_ fileURL: URL) async throws {
        guard workspace.open(fileURL) else {
            throw ExternalEditorLaunchFailure(fileURL: fileURL, editorName: "the default app")
        }
    }
}
