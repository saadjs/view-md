import XCTest
@testable import ViewMDCore

final class ExternalEditorTests: XCTestCase {
    func testInstalledEditorsFiltersCuratedEditorsToInstalledBundleIdentifiers() {
        let installedBundleIdentifiers: Set<String> = [
            "com.microsoft.VSCode",
            "dev.zed.Zed",
        ]

        let editors = ExternalEditorCatalog.installedEditors {
            installedBundleIdentifiers.contains($0)
        }

        XCTAssertEqual(editors, [
            ExternalEditor(name: "VS Code", bundleIdentifier: "com.microsoft.VSCode"),
            ExternalEditor(name: "Zed", bundleIdentifier: "dev.zed.Zed"),
        ])
    }

    func testInstalledEditorsUsesSublimeTextFourBeforeSublimeTextThree() {
        let editors = ExternalEditorCatalog.installedEditors { bundleIdentifier in
            bundleIdentifier == "com.sublimetext.4" || bundleIdentifier == "com.sublimetext.3"
        }

        XCTAssertEqual(editors, [
            ExternalEditor(name: "Sublime Text", bundleIdentifier: "com.sublimetext.4"),
        ])
    }

    func testInstalledEditorsFallsBackToSublimeTextThree() {
        let editors = ExternalEditorCatalog.installedEditors { bundleIdentifier in
            bundleIdentifier == "com.sublimetext.3"
        }

        XCTAssertEqual(editors, [
            ExternalEditor(name: "Sublime Text", bundleIdentifier: "com.sublimetext.3"),
        ])
    }

    func testPreferredEditorResolvesOnlyWhenInstalled() {
        let installedEditors = [
            ExternalEditor(name: "VS Code", bundleIdentifier: "com.microsoft.VSCode"),
        ]

        XCTAssertEqual(
            ExternalEditorCatalog.preferredEditor(
                bundleIdentifier: "com.microsoft.VSCode",
                installedEditors: installedEditors
            ),
            ExternalEditor(name: "VS Code", bundleIdentifier: "com.microsoft.VSCode")
        )
        XCTAssertNil(
            ExternalEditorCatalog.preferredEditor(
                bundleIdentifier: "dev.zed.Zed",
                installedEditors: installedEditors
            )
        )
    }
}
