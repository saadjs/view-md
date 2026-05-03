import Markdown
import XCTest
@testable import ViewMDCore

final class MarkdownPreviewBuilderTests: XCTestCase {
    func testParsesRepresentativeMarkdownBlocks() {
        let source = """
        # Title

        Paragraph with *emphasis*, **strong**, `code`, and [a link](https://saad.sh).

        - One
        - Two

        1. First
        2. Second

        > Quoted text

        ```swift
        let value = 1
        ```

        ---
        """

        let preview = MarkdownDocumentLoader().makePreviewDocument(source: source)

        XCTAssertEqual(preview.blocks.count, 7)
        XCTAssertEqual(preview.blocks.first, .heading(level: 1, inlines: [.text("Title")]))
        XCTAssertTrue(preview.blocks.contains(.horizontalRule))

        guard case .paragraph(let paragraph)? = preview.blocks.dropFirst().first else {
            return XCTFail("Expected paragraph block")
        }

        XCTAssertTrue(paragraph.contains(.emphasis([.text("emphasis")])))
        XCTAssertTrue(paragraph.contains(.strong([.text("strong")])))
        XCTAssertTrue(paragraph.contains(.inlineCode("code")))
        XCTAssertTrue(paragraph.contains(.link(destination: "https://saad.sh", children: [.text("a link")])))

        guard case .codeBlock(let language, let code)? = preview.blocks.dropLast().last else {
            return XCTFail("Expected code block")
        }

        XCTAssertEqual(language, "swift")
        XCTAssertEqual(code.trimmingCharacters(in: .whitespacesAndNewlines), "let value = 1")
    }

    func testEmptyDocumentProducesEmptyPreview() {
        let preview = MarkdownDocumentLoader().makePreviewDocument(source: "")

        XCTAssertTrue(preview.isEmpty)
        XCTAssertEqual(preview.blocks, [])
    }

    func testSwiftMarkdownParsingPathProducesDocument() {
        let document = Document(parsing: "## Parsed")
        let preview = MarkdownPreviewBuilder().build(from: document)

        XCTAssertEqual(preview.blocks, [
            .heading(level: 2, inlines: [.text("Parsed")])
        ])
    }
}
