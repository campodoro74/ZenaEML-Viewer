import Foundation
import UniformTypeIdentifiers

/// HTML document suitable for Quick Look data-based previews (and tests).
public struct PreviewDocument: Sendable {
    public let html: String
    public let attachments: [PreviewAttachment]

    public init(html: String, attachments: [PreviewAttachment] = []) {
        self.html = html
        self.attachments = attachments
    }
}

public struct PreviewAttachment: Sendable {
    public let id: String
    public let data: Data
    public let mimeType: String

    public init(id: String, data: Data, mimeType: String) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
    }

    public var contentType: UTType {
        UTType(mimeType: mimeType) ?? .data
    }
}

public enum PreviewHTML {
    /// Build a self-contained HTML preview with headers, body, and cid images as attachments.
    public static func build(from message: Message) -> PreviewDocument {
        let (attachments, cidMap) = collectInlineAttachments(from: message)
        let bodyHTML = renderBody(message: message, cidMap: cidMap)
        let attachmentHTML = renderAttachmentList(message.attachments)
        let html = renderDocument(message: message, bodyHTML: bodyHTML, attachmentHTML: attachmentHTML)
        return PreviewDocument(html: html, attachments: attachments)
    }

    private static func collectInlineAttachments(
        from message: Message
    ) -> (attachments: [PreviewAttachment], cidMap: [String: String]) {
        var attachments: [PreviewAttachment] = []
        var cidMap: [String: String] = [:]
        for (index, part) in message.inlineParts.enumerated() {
            guard let cid = part.contentID, !cid.isEmpty else { continue }
            let ext = preferredExtension(for: part.contentType)
            let id = "inline-\(index).\(ext)"
            attachments.append(PreviewAttachment(id: id, data: part.decodedBody(), mimeType: part.contentType))
            cidMap[cid.lowercased()] = id
        }
        return (attachments, cidMap)
    }

    private static func renderBody(message: Message, cidMap: [String: String]) -> String {
        if var html = message.htmlBody, !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            html = sanitizeHTML(html)
            html = rewriteCIDs(in: html, cidMap: cidMap)
            return wrapFragmentIfNeeded(html)
        }
        if let plain = message.plainBody, !plain.isEmpty {
            let style = "white-space:pre-wrap;font-family:-apple-system,BlinkMacSystemFont,Menlo,monospace;"
                + "font-size:13px;line-height:1.45;margin:0;"
            return "<pre style=\"\(style)\">\(escapeHTML(plain))</pre>"
        }
        return #"<p style="color:#888;">(No message body)</p>"#
    }

    private static func renderAttachmentList(_ attachmentList: [Part]) -> String {
        guard !attachmentList.isEmpty else { return "" }
        let items = attachmentList.map { part -> String in
            let name = escapeHTML(part.filename ?? "attachment")
            let type = escapeHTML(part.contentType)
            return "<li><strong>\(name)</strong> <span style=\"color:#888;\">(\(type))</span></li>"
        }.joined()
        return """
        <div class="attachments">
          <div class="label">Attachments</div>
          <ul>\(items)</ul>
        </div>
        """
    }

    private static func renderDocument(
        message: Message,
        bodyHTML: String,
        attachmentHTML: String
    ) -> String {
        let subject = escapeHTML(message.subject.isEmpty ? "(No subject)" : message.subject)
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          :root { color-scheme: light dark; }
          body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            font-size: 13px;
            line-height: 1.45;
            color: #1d1d1f;
            background: #fff;
          }
          @media (prefers-color-scheme: dark) {
            body { color: #f5f5f7; background: #1c1c1e; }
            .hdr { background: #2c2c2e; border-bottom-color: #3a3a3c; }
            .label { color: #98989d; }
            .attachments { border-top-color: #3a3a3c; }
          }
          .hdr {
            padding: 14px 16px 12px;
            background: #f5f5f7;
            border-bottom: 1px solid #d2d2d7;
          }
          .row { margin: 0 0 4px; word-break: break-word; }
          .label {
            display: inline-block;
            min-width: 4.5em;
            color: #6e6e73;
            font-weight: 600;
          }
          .subject { font-size: 16px; font-weight: 650; margin: 0 0 8px; }
          .body { padding: 16px; }
          .body img { max-width: 100%; height: auto; }
          .attachments {
            margin: 0 16px 16px;
            padding-top: 12px;
            border-top: 1px solid #d2d2d7;
          }
          .attachments ul { margin: 6px 0 0; padding-left: 1.2em; }
        </style>
        </head>
        <body>
          <div class="hdr">
            <div class="subject">\(subject)</div>
            \(headerRow("From", message.from))
            \(headerRow("To", message.to))
            \(headerRow("Cc", message.cc))
            \(headerRow("Date", message.date))
          </div>
          <div class="body">\(bodyHTML)</div>
          \(attachmentHTML)
        </body>
        </html>
        """
    }

    private static func headerRow(_ label: String, _ value: String) -> String {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        return #"<div class="row"><span class="label">\#(label)</span> \#(escapeHTML(value))</div>"#
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func sanitizeHTML(_ html: String) -> String {
        var result = html
        if let script = try? NSRegularExpression(
            pattern: #"<script\b[^>]*>[\s\S]*?</script>"#,
            options: [.caseInsensitive]
        ) {
            result = script.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        if let events = try? NSRegularExpression(
            pattern: #"\son[a-z]+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)"#,
            options: [.caseInsensitive]
        ) {
            result = events.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        return result
    }

    private static func rewriteCIDs(in html: String, cidMap: [String: String]) -> String {
        guard !cidMap.isEmpty else { return html }
        guard let regex = try? NSRegularExpression(
            pattern: #"cid:([^"'>\s]+)"#,
            options: [.caseInsensitive]
        ) else { return html }

        let ns = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length))
        var output = html
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let full = Range(match.range(at: 0), in: output),
                  let cidRange = Range(match.range(at: 1), in: output) else { continue }
            var cid = String(output[cidRange])
            cid = cid.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            let key = cid.removingPercentEncoding?.lowercased() ?? cid.lowercased()
            if let attachmentID = cidMap[key] {
                output.replaceSubrange(full, with: attachmentID)
            }
        }
        return output
    }

    private static func wrapFragmentIfNeeded(_ html: String) -> String {
        let lower = html.lowercased()
        if lower.contains("<html") || lower.contains("<body") {
            return html
        }
        return html
    }

    private static func preferredExtension(for mimeType: String) -> String {
        switch mimeType.lowercased() {
        case "image/jpeg", "image/jpg": return "jpg"
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "image/webp": return "webp"
        case "image/svg+xml": return "svg"
        case "application/pdf": return "pdf"
        default:
            if let subtype = mimeType.split(separator: "/").last, !subtype.isEmpty {
                return String(subtype).replacingOccurrences(of: "+xml", with: "")
            }
            return "bin"
        }
    }
}
