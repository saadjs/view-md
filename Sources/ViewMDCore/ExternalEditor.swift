import Foundation

public struct ExternalEditor: Equatable, Identifiable, Sendable {
    public var id: String { bundleIdentifier }

    public let name: String
    public let bundleIdentifier: String

    public init(name: String, bundleIdentifier: String) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct ExternalEditorCandidate: Equatable, Sendable {
    public let name: String
    public let bundleIdentifiers: [String]

    public init(name: String, bundleIdentifiers: [String]) {
        self.name = name
        self.bundleIdentifiers = bundleIdentifiers
    }
}

public enum ExternalEditorCatalog {
    public static let candidates: [ExternalEditorCandidate] = [
        ExternalEditorCandidate(name: "VS Code", bundleIdentifiers: ["com.microsoft.VSCode"]),
        ExternalEditorCandidate(name: "Xcode", bundleIdentifiers: ["com.apple.dt.Xcode"]),
        ExternalEditorCandidate(name: "Zed", bundleIdentifiers: ["dev.zed.Zed"]),
        ExternalEditorCandidate(name: "Sublime Text", bundleIdentifiers: [
            "com.sublimetext.4",
            "com.sublimetext.3",
        ]),
    ]

    public static func installedEditors(
        candidates: [ExternalEditorCandidate] = candidates,
        isInstalled: (String) -> Bool
    ) -> [ExternalEditor] {
        candidates.compactMap { candidate in
            guard let bundleIdentifier = candidate.bundleIdentifiers.first(where: isInstalled) else {
                return nil
            }
            return ExternalEditor(name: candidate.name, bundleIdentifier: bundleIdentifier)
        }
    }

    public static func preferredEditor(
        bundleIdentifier: String?,
        installedEditors: [ExternalEditor]
    ) -> ExternalEditor? {
        guard let bundleIdentifier else {
            return nil
        }
        return installedEditors.first { $0.bundleIdentifier == bundleIdentifier }
    }
}

public struct ExternalEditorPreferences {
    public static let preferredBundleIdentifierKey = "ViewMD.preferredExternalEditorBundleIdentifier"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var preferredBundleIdentifier: String? {
        get {
            defaults.string(forKey: Self.preferredBundleIdentifierKey)
        }
        set {
            defaults.set(newValue, forKey: Self.preferredBundleIdentifierKey)
        }
    }
}
