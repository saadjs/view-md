import SwiftUI

public struct MarkdownPreviewView: View {
    private let document: MarkdownPreviewDocument

    public init(document: MarkdownPreviewDocument) {
        self.document = document
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if document.isEmpty {
                    Text("Empty Markdown file")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .preferredColorScheme(nil)
    }

    private func blockView(_ block: MarkdownBlock) -> AnyView {
        switch block {
        case .heading(let level, let inlines):
            return AnyView(inlineText(inlines)
                .font(headingFont(for: level))
                .fontWeight(level <= 2 ? .semibold : .medium)
                .foregroundStyle(.primary)
                .lineSpacing(2)
                .padding(.top, level == 1 ? 2 : 6))
        case .paragraph(let inlines):
            return AnyView(inlineText(inlines)
                .font(.body)
                .lineSpacing(4)
                .textSelection(.enabled))
        case .unorderedList(let items):
            return AnyView(listView(items: items, orderedStart: nil))
        case .orderedList(let start, let items):
            return AnyView(listView(items: items, orderedStart: start))
        case .blockQuote(let blocks):
            return AnyView(HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 2)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, nestedBlock in
                        blockView(nestedBlock)
                    }
                }
            }
            .foregroundStyle(.secondary))
        case .codeBlock(let language, let code):
            return AnyView(VStack(alignment: .leading, spacing: 8) {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6)))
        case .horizontalRule:
            return AnyView(Divider()
                .padding(.vertical, 6))
        }
    }

    private func listView(items: [MarkdownListItem], orderedStart: UInt?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    Text(marker(for: item, index: index, orderedStart: orderedStart))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: orderedStart == nil ? 14 : 28, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(item.blocks.enumerated()), id: \.offset) { _, block in
                            blockView(block)
                        }
                    }
                }
            }
        }
    }

    private func marker(for item: MarkdownListItem, index: Int, orderedStart: UInt?) -> String {
        if let checkbox = item.checkbox {
            return checkbox == .checked ? "[x]" : "[ ]"
        }
        if let orderedStart {
            return "\(orderedStart + UInt(index))."
        }
        return "•"
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            return .system(size: 30, weight: .semibold)
        case 2:
            return .system(size: 24, weight: .semibold)
        case 3:
            return .system(size: 20, weight: .medium)
        default:
            return .headline
        }
    }

    private func inlineText(_ inlines: [MarkdownInline]) -> Text {
        Text(attributedString(for: inlines))
    }

    private func attributedString(for inlines: [MarkdownInline]) -> AttributedString {
        var result = AttributedString()
        for inline in inlines {
            result.append(attributedString(for: inline))
        }
        return result
    }

    private func attributedString(for inline: MarkdownInline) -> AttributedString {
        switch inline {
        case .text(let value):
            return AttributedString(value)
        case .emphasis(let children):
            var string = attributedString(for: children)
            addIntent(.emphasized, to: &string)
            return string
        case .strong(let children):
            var string = attributedString(for: children)
            addIntent(.stronglyEmphasized, to: &string)
            return string
        case .inlineCode(let code):
            var string = AttributedString(code)
            string.inlinePresentationIntent = .code
            return string
        case .link(let destination, let children):
            var string = attributedString(for: children)
            applyLink(destination, to: &string)
            return string
        case .lineBreak:
            return AttributedString("\n")
        }
    }

    private func addIntent(_ intent: InlinePresentationIntent, to string: inout AttributedString) {
        let snapshot = string.runs.map { ($0.range, $0.inlinePresentationIntent ?? []) }
        for (range, existing) in snapshot {
            string[range].inlinePresentationIntent = existing.union(intent)
        }
    }

    private func applyLink(_ destination: String?, to string: inout AttributedString) {
        guard let trimmed = destination?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              let url = URL(string: trimmed) else {
            return
        }
        let ranges = string.runs.map(\.range)
        for range in ranges {
            string[range].link = url
            string[range].foregroundColor = .accentColor
            string[range].underlineStyle = .single
        }
    }
}
