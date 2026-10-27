import Foundation

public struct Message {
    public let root: Part

    public init(data: Data) {
        if MSG.isMSG(data), let part = MSG.parse(data) {
            self.root = part
        } else {
            self.root = MIME.parse(data)
        }
    }

    public init(url: URL) throws {
        let data = try Data(contentsOf: url)
        self.init(data: data)
    }

    public var headers: [(String, String)] { root.rawHeaders }

    public var from: String { decodedHeader("From") }
    public var to: String { decodedHeader("To") }
    public var cc: String { decodedHeader("Cc") }
    public var bcc: String { decodedHeader("Bcc") }
    public var subject: String { decodedHeader("Subject") }
    public var date: String { decodedHeader("Date") }
    public var replyTo: String { decodedHeader("Reply-To") }

    public func decodedHeader(_ name: String) -> String {
        guard let raw = root.header(name) else { return "" }
        return Decoding.decodeEncodedWords(raw)
    }

    // MARK: - Bodies

    public var htmlBody: String? {
        guard let part = findBodyPart(contentType: "text/html") else { return nil }
        return part.decodedText()
    }

    public var plainBody: String? {
        guard let part = findBodyPart(contentType: "text/plain") else { return nil }
        return part.decodedText()
    }

    public func findBodyPart(contentType: String) -> Part? {
        findBody(root, contentType: contentType)
    }

    /// Depth-first search for a non-empty body part. Skips empty wrappers (common in
    /// PEC / “Fwd:” shells that only carry a nested `message/rfc822`).
    private func findBody(_ part: Part, contentType: String) -> Part? {
        if part.contentType == contentType,
           part.disposition?.lowercased() != "attachment" {
            let text = part.decodedText().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return part
            }
        }
        for sub in part.parts {
            if let found = findBody(sub, contentType: contentType) {
                return found
            }
        }
        return nil
    }

    // MARK: - Attachments / inlines

    public var attachments: [Part] {
        var out: [Part] = []
        collectAttachments(root, into: &out)
        return out
    }

    public var inlineParts: [Part] {
        var out: [Part] = []
        collectInlines(root, into: &out)
        return out
    }

    private func collectAttachments(_ part: Part, into: inout [Part]) {
        if !part.isMultipart {
            let disp = part.disposition?.lowercased()
            let isExplicitAttachment = disp == "attachment"
            let isBodyText = (part.contentType == "text/plain" || part.contentType == "text/html") &&
                             disp != "attachment"
            let hasName = part.filename != nil
            let isNestedMail = MIME.isNestedMessage(part.contentType)
            // Nested emails (message/rfc822): list when named or explicitly attached so
            // the user can open the inner .eml; still recurse so inner files appear too.
            if isExplicitAttachment
                || (!isBodyText && hasName && disp != "inline")
                || (isNestedMail && (isExplicitAttachment || hasName)) {
                into.append(part)
            }
        }
        for sub in part.parts { collectAttachments(sub, into: &into) }
    }

    private func collectInlines(_ part: Part, into: inout [Part]) {
        if !part.isMultipart, part.contentID != nil {
            let disp = part.disposition?.lowercased()
            let isTextBody = part.contentType == "text/plain" || part.contentType == "text/html"
            if disp == "inline" || (!isTextBody && disp != "attachment") {
                into.append(part)
            }
        }
        for sub in part.parts { collectInlines(sub, into: &into) }
    }

    // MARK: - CID resolution

    public func partByContentID(_ cid: String) -> Part? {
        let clean = cid.trimmingCharacters(in: CharacterSet(charactersIn: "<> \t\r\n"))
        var found: Part?
        walk(root) { p in
            if found == nil, let id = p.contentID, id == clean {
                found = p
            }
        }
        return found
    }

    private func walk(_ part: Part, _ visit: (Part) -> Void) {
        visit(part)
        for sub in part.parts { walk(sub, visit) }
    }
}
