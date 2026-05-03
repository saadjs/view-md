import AppKit
import SwiftUI

@main
struct ViewMDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 520, minHeight: 360)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    NotificationCenter.default.post(name: .viewMDOpenDocument, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let viewMDOpenDocument = Notification.Name("ViewMDOpenDocument")
    static let viewMDOpenURLs = Notification.Name("ViewMDOpenURLs")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        ExternalDocumentOpenRelay.publish(urls)
    }
}

@MainActor
enum ExternalDocumentOpenRelay {
    private static var pendingURLs: [URL] = []

    static func publish(_ urls: [URL]) {
        pendingURLs = urls
        NotificationCenter.default.post(name: .viewMDOpenURLs, object: urls)
    }

    static func consumePendingURLs() -> [URL] {
        defer { pendingURLs = [] }
        return pendingURLs
    }

    static func clearPendingURLs() {
        pendingURLs = []
    }
}
