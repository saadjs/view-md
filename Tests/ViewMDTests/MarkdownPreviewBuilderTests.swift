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

    func testStandaloneImageBecomesImageBlock() {
        let preview = MarkdownDocumentLoader().makePreviewDocument(
            source: "![alt text](https://example.com/img.png)"
        )

        XCTAssertEqual(preview.blocks, [
            .image(source: "https://example.com/img.png", alt: "alt text")
        ])
    }

    func testLinkWrappedImageBecomesImageBlock() {
        let preview = MarkdownDocumentLoader().makePreviewDocument(
            source: "[![badge](https://example.com/badge.svg)](https://example.com)"
        )

        XCTAssertEqual(preview.blocks, [
            .image(source: "https://example.com/badge.svg", alt: "badge")
        ])
    }

    func testRowOfImagesProducesMultipleImageBlocks() {
        let preview = MarkdownDocumentLoader().makePreviewDocument(
            source: "![a](https://example.com/a.png) ![b](https://example.com/b.png)"
        )

        XCTAssertEqual(preview.blocks, [
            .image(source: "https://example.com/a.png", alt: "a"),
            .image(source: "https://example.com/b.png", alt: "b"),
        ])
    }

    func testImageMixedWithTextStaysAsParagraph() {
        let preview = MarkdownDocumentLoader().makePreviewDocument(
            source: "Look at ![cat](https://example.com/cat.png) here"
        )

        guard case .paragraph? = preview.blocks.first else {
            return XCTFail("Expected paragraph block, got \(preview.blocks)")
        }
    }

    func testResolvesRelativeImageURLAgainstMarkdownFile() {
        let documentURL = URL(fileURLWithPath: "/Users/example/Docs/readme.md")
        let resolved = MarkdownImageURLResolver.resolve(
            source: "images/photo.png",
            documentURL: documentURL
        )

        XCTAssertEqual(
            resolved,
            URL(fileURLWithPath: "/Users/example/Docs/images/photo.png")
        )
    }

    func testResolvesRelativeImageURLWithSpaces() {
        let documentURL = URL(fileURLWithPath: "/Users/example/Docs/readme.md")
        let resolved = MarkdownImageURLResolver.resolve(
            source: "images/photo one.png",
            documentURL: documentURL
        )

        XCTAssertEqual(
            resolved,
            URL(fileURLWithPath: "/Users/example/Docs/images/photo one.png")
        )
    }

    func testResolvesRelativeImageURLWithExistingEscapes() {
        let documentURL = URL(fileURLWithPath: "/Users/example/Docs/readme.md")
        let resolved = MarkdownImageURLResolver.resolve(
            source: "images/photo%20one.png",
            documentURL: documentURL
        )

        XCTAssertEqual(
            resolved,
            URL(fileURLWithPath: "/Users/example/Docs/images/photo one.png")
        )
    }

    func testResolvesRelativeImageURLWithQuery() {
        let documentURL = URL(fileURLWithPath: "/Users/example/Docs/readme.md")
        let resolved = MarkdownImageURLResolver.resolve(
            source: "images/photo.png?raw=1",
            documentURL: documentURL
        )

        XCTAssertEqual(
            resolved,
            URL(string: "file:///Users/example/Docs/images/photo.png?raw=1")
        )
    }

    func testKeepsRemoteImageURL() {
        let resolved = MarkdownImageURLResolver.resolve(
            source: "https://example.com/image.svg",
            documentURL: URL(fileURLWithPath: "/Users/example/Docs/readme.md")
        )

        XCTAssertEqual(resolved, URL(string: "https://example.com/image.svg"))
    }

    func testResolvesAbsoluteImagePathAsFileURL() {
        let resolved = MarkdownImageURLResolver.resolve(
            source: "/Users/example/Images/photo.png",
            documentURL: URL(fileURLWithPath: "/Users/example/Docs/readme.md")
        )

        XCTAssertEqual(resolved, URL(fileURLWithPath: "/Users/example/Images/photo.png"))
    }
}
