import Foundation

public struct MarkdownPreviewDocument: Equatable, Sendable {
    public var sourceURL: URL?
    public var blocks: [MarkdownBlock]

    public init(sourceURL: URL? = nil, blocks: [MarkdownBlock]) {
        self.sourceURL = sourceURL
        self.blocks = blocks
    }

    public var displayName: String {
        sourceURL?.lastPathComponent ?? "Untitled Markdown"
    }

    public var isEmpty: Bool {
        blocks.isEmpty
    }
}

public struct MarkdownListItem: Equatable, Sendable {
    public var checkbox: MarkdownCheckbox?
    public var blocks: [MarkdownBlock]

    public init(checkbox: MarkdownCheckbox? = nil, blocks: [MarkdownBlock]) {
        self.checkbox = checkbox
        self.blocks = blocks
    }
}

public enum MarkdownCheckbox: Equatable, Sendable {
    case checked
    case unchecked
}

public indirect enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, inlines: [MarkdownInline])
    case paragraph([MarkdownInline])
    case unorderedList([MarkdownListItem])
    case orderedList(start: UInt, items: [MarkdownListItem])
    case blockQuote([MarkdownBlock])
    case codeBlock(language: String?, code: String)
    case horizontalRule
}

public indirect enum MarkdownInline: Equatable, Sendable {
    case text(String)
    case emphasis([MarkdownInline])
    case strong([MarkdownInline])
    case inlineCode(String)
    case link(destination: String?, children: [MarkdownInline])
    case lineBreak
}
