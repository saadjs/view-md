import Foundation
import XCTest
@testable import ViewMDCore

final class MarkdownFileReaderTests: XCTestCase {
    func testReadsUTF8MarkdownFile() throws {
        let url = try temporaryFile(contents: "# Hello\n\nA UTF-8 check: café.")

        let source = try MarkdownFileReader().read(from: url)

        XCTAssertEqual(source, "# Hello\n\nA UTF-8 check: café.")
    }

    func testRejectsNonUTF8MarkdownFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try Data([0xFF, 0xFE, 0x00]).write(to: url)

        XCTAssertThrowsError(try MarkdownFileReader().read(from: url)) { error in
            XCTAssertEqual(error as? MarkdownFileReaderError, .unsupportedEncoding(url))
        }
    }

    private func temporaryFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try contents.data(using: .utf8)?.write(to: url)
        return url
    }
}
