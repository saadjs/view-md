import AppKit
import SwiftUI

@main
struct ViewMDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .frame(minWidth: 520, minHeight: 360)
                .modifier(WindowOpenerInstaller())
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    WindowTabCommands.openNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)
                OpenDocumentMenuButton()
            }
            CommandGroup(after: .windowList) {
                Divider()
                ForEach(1...9, id: \.self) { index in
                    Button("Show Tab \(index)") {
                        WindowTabCommands.selectTab(at: index - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
                }
            }
        }
    }
}

private struct WindowOpenerInstaller: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            WindowOpenerStore.open = { openWindow(id: "main") }
        }
    }
}

private struct OpenDocumentMenuButton: View {
    @FocusedValue(\.openDocumentAction) private var openAction

    var body: some View {
        Button("Open...") {
            openAction?()
        }
        .keyboardShortcut("o", modifiers: .command)
        .disabled(openAction == nil)
    }
}

struct OpenDocumentActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var openDocumentAction: (() -> Void)? {
        get { self[OpenDocumentActionKey.self] }
        set { self[OpenDocumentActionKey.self] = newValue }
    }
}

@MainActor
enum WindowOpenerStore {
    static var open: (() -> Void)?
}

@MainActor
enum WindowTabCommands {
    static func selectTab(at index: Int) {
        guard let window = NSApp.keyWindow,
              let tabs = window.tabbedWindows,
              index < tabs.count else {
            return
        }
        tabs[index].makeKeyAndOrderFront(nil)
    }

    static func openNewTab() {
        guard let parent = NSApp.keyWindow else {
            WindowOpenerStore.open?()
            return
        }

        let hosting = NSHostingController(
            rootView: ContentView().frame(minWidth: 520, minHeight: 360)
        )
        let tab = TabbingHostingWindow(contentViewController: hosting)
        tab.styleMask = parent.styleMask
        tab.titlebarAppearsTransparent = parent.titlebarAppearsTransparent
        tab.titleVisibility = parent.titleVisibility
        tab.toolbarStyle = parent.toolbarStyle
        tab.tabbingMode = .preferred
        tab.tabbingIdentifier = parent.tabbingIdentifier
        tab.title = "ViewMD"
        tab.setFrame(parent.frame, display: false)

        parent.addTabbedWindow(tab, ordered: .above)
        tab.makeKeyAndOrderFront(nil)
    }
}

final class TabbingHostingWindow: NSWindow {
    @objc override func newWindowForTab(_ sender: Any?) {
        WindowOpenerStore.open?()
    }
}

extension Notification.Name {
    static let viewMDOpenURLs = Notification.Name("ViewMDOpenURLs")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow,
                  !(window is TabbingHostingWindow),
                  String(describing: type(of: window)).contains("SwiftUI") else {
                return
            }
            object_setClass(window, TabbingHostingWindow.self)
            MainActor.assumeIsolated {
                window.tabbingMode = .preferred
                window.tabbingIdentifier = "ViewMDMain"
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        ExternalDocumentOpenRelay.publish(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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
