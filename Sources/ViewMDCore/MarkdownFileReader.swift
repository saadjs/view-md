import Foundation

public enum MarkdownFileReaderError: Error, Equatable, LocalizedError, Sendable {
    case notAFileURL(URL)
    case unsupportedEncoding(URL)

    public var errorDescription: String? {
        switch self {
        case .notAFileURL(let url):
            "Expected a file URL, got \(url.absoluteString)."
        case .unsupportedEncoding(let url):
            "Could not read \(url.lastPathComponent) as UTF-8 Markdown."
        }
    }
}

public struct MarkdownFileReader: Sendable {
    public init() {}

    public func read(from url: URL) throws -> String {
        guard url.isFileURL else {
            throw MarkdownFileReaderError.notAFileURL(url)
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard !data.isEmpty else {
            return ""
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw MarkdownFileReaderError.unsupportedEncoding(url)
        }
        return text
    }
}
