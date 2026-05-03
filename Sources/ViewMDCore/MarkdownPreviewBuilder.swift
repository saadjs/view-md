import Foundation
import Markdown

public struct MarkdownDocumentLoader: Sendable {
    private let reader: MarkdownFileReader
    private let builder: MarkdownPreviewBuilder

    public init(
        reader: MarkdownFileReader = MarkdownFileReader(),
        builder: MarkdownPreviewBuilder = MarkdownPreviewBuilder()
    ) {
        self.reader = reader
        self.builder = builder
    }

    public func load(from url: URL) throws -> MarkdownPreviewDocument {
        let source = try reader.read(from: url)
        return makePreviewDocument(source: source, sourceURL: url)
    }

    public func makePreviewDocument(source: String, sourceURL: URL? = nil) -> MarkdownPreviewDocument {
        let parsedDocument = Document(parsing: source, source: sourceURL)
        return builder.build(from: parsedDocument, sourceURL: sourceURL)
    }
}

public struct MarkdownPreviewBuilder: Sendable {
    public init() {}

    public func build(from document: Document, sourceURL: URL? = nil) -> MarkdownPreviewDocument {
        MarkdownPreviewDocument(
            sourceURL: sourceURL,
            blocks: document.children.flatMap { blocks(from: $0) }
        )
    }

    private func blocks(from markup: Markup) -> [MarkdownBlock] {
        switch markup {
        case let heading as Heading:
            return [.heading(level: heading.level, inlines: inlines(from: heading.children))]
        case let paragraph as Paragraph:
            if let imageBlocks = imageBlocks(from: paragraph) {
                return imageBlocks
            }
            let content = inlines(from: paragraph.children)
            return content.isEmpty ? [] : [.paragraph(content)]
        case let unorderedList as UnorderedList:
            return [.unorderedList(unorderedList.children.compactMap { listItem(from: $0) })]
        case let orderedList as OrderedList:
            return [.orderedList(
                start: orderedList.startIndex,
                items: orderedList.children.compactMap { listItem(from: $0) }
            )]
        case let quote as BlockQuote:
            return [.blockQuote(quote.children.flatMap { blocks(from: $0) })]
        case let codeBlock as CodeBlock:
            return [.codeBlock(language: codeBlock.language, code: codeBlock.code)]
        case is ThematicBreak:
            return [.horizontalRule]
        default:
            return markup.children.flatMap { blocks(from: $0) }
        }
    }

    private func imageBlocks(from paragraph: Paragraph) -> [MarkdownBlock]? {
        var result: [MarkdownBlock] = []
        for child in paragraph.children {
            switch child {
            case let image as Markdown.Image:
                guard let block = imageBlock(from: image) else { return nil }
                result.append(block)
            case let link as Markdown.Link:
                let linkChildren = Array(link.children)
                guard linkChildren.count == 1,
                      let image = linkChildren.first as? Markdown.Image,
                      let block = imageBlock(from: image) else {
                    return nil
                }
                result.append(block)
            case let text as Markdown.Text where text.string.trimmingCharacters(in: .whitespaces).isEmpty:
                continue
            case is SoftBreak, is LineBreak:
                continue
            default:
                return nil
            }
        }
        return result.isEmpty ? nil : result
    }

    private func imageBlock(from image: Markdown.Image) -> MarkdownBlock? {
        guard let source = image.source, !source.isEmpty else { return nil }
        return .image(source: source, alt: image.plainText)
    }

    private func listItem(from markup: Markup) -> MarkdownListItem? {
        guard let listItem = markup as? ListItem else {
            return nil
        }

        let checkbox: MarkdownCheckbox?
        switch listItem.checkbox {
        case .checked:
            checkbox = .checked
        case .unchecked:
            checkbox = .unchecked
        case .none:
            checkbox = nil
        }

        return MarkdownListItem(
            checkbox: checkbox,
            blocks: listItem.children.flatMap { blocks(from: $0) }
        )
    }

    private func inlines(from children: MarkupChildren) -> [MarkdownInline] {
        children.flatMap { inline(from: $0) }
    }

    private func inline(from markup: Markup) -> [MarkdownInline] {
        switch markup {
        case let text as Markdown.Text:
            return [.text(text.string)]
        case let code as InlineCode:
            return [.inlineCode(code.code)]
        case let emphasis as Emphasis:
            return [.emphasis(inlines(from: emphasis.children))]
        case let strong as Strong:
            return [.strong(inlines(from: strong.children))]
        case let link as Link:
            return [.link(destination: link.destination, children: inlines(from: link.children))]
        case is LineBreak:
            return [.lineBreak]
        case is SoftBreak:
            return [.text(" ")]
        default:
            return markup.children.flatMap { inline(from: $0) }
        }
    }
}
