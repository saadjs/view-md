import SwiftUI
import WebKit

struct RemoteImageView: View {
    let url: URL?
    let alt: String
    let maxWidth: CGFloat
    let maxHeight: CGFloat

    @State private var loaded: LoadState = .pending

    init(url: URL?, alt: String, maxWidth: CGFloat = 480, maxHeight: CGFloat = 360) {
        self.url = url
        self.alt = alt
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }

    var body: some View {
        content
            .task(id: url) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch loaded {
        case .pending:
            ProgressView()
                .controlSize(.small)
                .frame(minHeight: 32)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .raster(let image):
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(alt)
        case .svg(let data, let intrinsicSize):
            let size = clamp(size: intrinsicSize)
            SVGWebView(data: data)
                .frame(width: size.width, height: size.height)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(alt)
        case .failed:
            Text(alt.isEmpty ? (url?.absoluteString ?? "Image") : alt)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func clamp(size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: min(200, maxWidth), height: min(100, maxHeight))
        }
        let scale = min(1, min(maxWidth / size.width, maxHeight / size.height))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    private func load() async {
        guard let url else {
            loaded = .failed
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let mime = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            let isSVG = mime.contains("svg")
                || url.pathExtension.lowercased() == "svg"
                || RemoteImageView.looksLikeSVG(data)
            if isSVG {
                let size = RemoteImageView.parseSVGIntrinsicSize(data) ?? CGSize(width: 200, height: 100)
                loaded = .svg(data, size)
            } else if let image = NSImage(data: data) {
                loaded = .raster(image)
            } else {
                loaded = .failed
            }
        } catch {
            loaded = .failed
        }
    }

    static func looksLikeSVG(_ data: Data) -> Bool {
        guard let prefix = String(data: data.prefix(256), encoding: .utf8)?.lowercased() else { return false }
        return prefix.contains("<svg") || (prefix.contains("<?xml") && prefix.contains("svg"))
    }

    static func parseSVGIntrinsicSize(_ data: Data) -> CGSize? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        guard let openRange = text.range(of: "<svg") else { return nil }
        guard let closeRange = text.range(of: ">", range: openRange.upperBound..<text.endIndex) else { return nil }
        let tag = String(text[openRange.upperBound..<closeRange.lowerBound])

        let width = attribute("width", in: tag).flatMap(parseLength)
        let height = attribute("height", in: tag).flatMap(parseLength)
        if let width, let height {
            return CGSize(width: width, height: height)
        }
        if let viewBox = attribute("viewBox", in: tag) {
            let nums = viewBox
                .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\t" || $0 == "\n" })
                .compactMap { Double($0) }
            if nums.count >= 4 {
                return CGSize(width: nums[2], height: nums[3])
            }
        }
        return nil
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = #"\b\#(name)\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(tag.startIndex..., in: tag)
        guard let match = regex.firstMatch(in: tag, range: range),
              let captureRange = Range(match.range(at: 1), in: tag) else { return nil }
        return String(tag[captureRange])
    }

    private static func parseLength(_ raw: String) -> CGFloat? {
        let cleaned = raw
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "[a-zA-Z%]", with: "", options: .regularExpression)
        return Double(cleaned).map { CGFloat($0) }
    }

    private enum LoadState {
        case pending
        case raster(NSImage)
        case svg(Data, CGSize)
        case failed
    }
}

private struct SVGWebView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.allowsLinkPreview = false
        view.allowsBackForwardNavigationGestures = false
        return view
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let svg = String(data: data, encoding: .utf8) ?? ""
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
          svg { width: 100%; height: 100%; display: block; }
        </style>
        </head>
        <body>\(svg)</body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
