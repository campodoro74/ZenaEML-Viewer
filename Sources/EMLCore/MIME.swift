import Foundation

public struct Part {
    public var rawHeaders: [(String, String)] = []
    public var body: Data = Data()
    public var parts: [Part] = []

    public var contentType: String = "text/plain"
    public var contentTypeParams: [String: String] = [:]
    public var encoding: String = "7bit"
    public var disposition: String?
    public var dispositionParams: [String: String] = [:]
    public var contentID: String?

    public var charset: String? { contentTypeParams["charset"] }
    public var boundary: String? { contentTypeParams["boundary"] }
    public var isMultipart: Bool { contentType.hasPrefix("multipart/") }

    public var filename: String? {
        if let n = dispositionParams["filename"] { return n }
        if let n = contentTypeParams["name"] { return n }
        return nil
    }

    public func header(_ name: String) -> String? {
        let key = name.lowercased()
        return rawHeaders.first { $0.0.lowercased() == key }?.1
    }

    public func decodedBody() -> Data {
        switch encoding.lowercased() {
        case "base64":
            let s = String(data: body, encoding: .ascii) ?? String(data: body, encoding: .isoLatin1) ?? ""
            return Decoding.base64(s)
        case "quoted-printable":
            return Decoding.quotedPrintable(body)
        default:
            return body
        }
    }

    public func decodedText() -> String {
        Decoding.string(from: decodedBody(), charset: charset)
    }
}

public enum MIME {

    public static func parse(_ data: Data) -> Part {
        parsePart(data, depth: 0)
    }

    private static let maxNestingDepth = 12

    private static func parsePart(_ data: Data, depth: Int) -> Part {
        var part = Part()
        let (headerData, bodyData) = splitHeadersBody(data)
        part.rawHeaders = parseHeaders(headerData)
        part.body = bodyData

        if let ct = part.header("Content-Type") {
            let (type, params) = parseStructuredHeader(ct)
            part.contentType = type.lowercased()
            part.contentTypeParams = params
        }
        if let cte = part.header("Content-Transfer-Encoding") {
            part.encoding = cte.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        if let cd = part.header("Content-Disposition") {
            let (type, params) = parseStructuredHeader(cd)
            part.disposition = type.lowercased()
            part.dispositionParams = params
        }
        if let cid = part.header("Content-ID") {
            let trim = CharacterSet(charactersIn: "<> \t\r\n")
            part.contentID = cid.trimmingCharacters(in: trim)
        }

        if part.isMultipart, let b = part.boundary, !b.isEmpty {
            part.parts = splitMultipart(bodyData, boundary: b).map { parsePart($0, depth: depth) }
        } else if depth < maxNestingDepth, Self.isNestedMessage(part.contentType) {
            // message/rfc822 (and siblings): body is a full RFC 822 message — parse and nest
            // so findBody / attachments / cid walk can see the inner tree (PEC forwards, etc.).
            let nestedData = part.decodedBody()
            if !nestedData.isEmpty {
                part.parts = [parsePart(nestedData, depth: depth + 1)]
            }
        }
        return part
    }

    /// Content types whose body is another email message (not a multipart container).
    public static func isNestedMessage(_ contentType: String) -> Bool {
        switch contentType.lowercased() {
        case "message/rfc822", "message/global", "message/news", "message/rfc822-headers":
            return true
        default:
            return false
        }
    }

    // MARK: - Header parsing

    private static func splitHeadersBody(_ data: Data) -> (Data, Data) {
        if let r = range(of: [0x0D, 0x0A, 0x0D, 0x0A], in: data) {
            return (data.subdata(in: data.startIndex..<r.lowerBound),
                    data.subdata(in: r.upperBound..<data.endIndex))
        }
        if let r = range(of: [0x0A, 0x0A], in: data) {
            return (data.subdata(in: data.startIndex..<r.lowerBound),
                    data.subdata(in: r.upperBound..<data.endIndex))
        }
        return (data, Data())
    }

    private static func parseHeaders(_ data: Data) -> [(String, String)] {
        guard let raw = String(data: data, encoding: .isoLatin1) else { return [] }
        let rawLines = raw.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var unfolded: [String] = []
        for line in rawLines {
            if let first = line.first, first == " " || first == "\t" {
                if !unfolded.isEmpty {
                    unfolded[unfolded.count - 1] += " " + line.trimmingCharacters(in: .whitespaces)
                }
            } else {
                unfolded.append(line)
            }
        }

        var result: [(String, String)] = []
        for line in unfolded {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            result.append((name, value))
        }
        return result
    }

    public static func parseStructuredHeader(_ s: String) -> (String, [String: String]) {
        var segments: [String] = []
        var current = ""
        var inQuotes = false
        for c in s {
            if c == "\"" {
                inQuotes.toggle()
                current.append(c)
            } else if c == ";" && !inQuotes {
                segments.append(current)
                current = ""
            } else {
                current.append(c)
            }
        }
        if !current.isEmpty { segments.append(current) }

        let main = segments.first?.trimmingCharacters(in: .whitespaces) ?? ""

        var raw: [(String, String)] = []
        for seg in segments.dropFirst() {
            let kv = seg.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { continue }
            let k = kv[0].trimmingCharacters(in: .whitespaces).lowercased()
            var v = kv[1].trimmingCharacters(in: .whitespaces)
            if v.hasPrefix("\"") && v.hasSuffix("\"") && v.count >= 2 {
                v = String(v.dropFirst().dropLast())
            }
            raw.append((k, v))
        }

        var params: [String: String] = [:]
        var continuations: [String: [Int: String]] = [:]
        var rfc2231: [String: (charset: String?, lang: String?, value: String)] = [:]

        for (k, v) in raw {
            if let asterisk = k.firstIndex(of: "*") {
                let base = String(k[..<asterisk])
                let rest = String(k[k.index(after: asterisk)...])
                if rest.isEmpty {
                    // name* = charset'lang'encoded
                    let parts = v.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
                    if parts.count == 3 {
                        rfc2231[base] = (parts[0].isEmpty ? nil : parts[0],
                                         parts[1].isEmpty ? nil : parts[1],
                                         parts[2])
                    } else {
                        params[base] = v
                    }
                } else {
                    let encoded = rest.hasSuffix("*")
                    let numStr = encoded ? String(rest.dropLast()) : rest
                    if let idx = Int(numStr) {
                        continuations[base, default: [:]][idx] = encoded ? percentDecode(v) : v
                    } else {
                        params[k] = v
                    }
                }
            } else {
                params[k] = v
            }
        }

        for (name, chunks) in continuations {
            let joined = chunks.keys.sorted().map { chunks[$0] ?? "" }.joined()
            if let (cs, _, encoded) = rfc2231[name] {
                let decoded = percentDecode(encoded + joined)
                let data = decoded.data(using: .isoLatin1) ?? Data(decoded.utf8)
                params[name] = Decoding.string(from: data, charset: cs)
            } else {
                params[name] = joined
            }
        }
        for (name, parts) in rfc2231 where continuations[name] == nil {
            let decoded = percentDecode(parts.value)
            let data = decoded.data(using: .isoLatin1) ?? Data(decoded.utf8)
            params[name] = Decoding.string(from: data, charset: parts.charset)
        }
        return (main, params)
    }

    private static func percentDecode(_ s: String) -> String {
        var out = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            if chars[i] == "%", i + 2 < chars.count,
               let hi = Int(String(chars[i + 1]), radix: 16),
               let lo = Int(String(chars[i + 2]), radix: 16) {
                let byte = UInt8((hi << 4) | lo)
                if let scalar = Unicode.Scalar(UInt32(byte)) {
                    out.append(Character(scalar))
                }
                i += 3
            } else {
                out.append(chars[i]); i += 1
            }
        }
        return out
    }

    // MARK: - Multipart split

    private static func splitMultipart(_ data: Data, boundary: String) -> [Data] {
        let sep = "--" + boundary
        guard let sepData = sep.data(using: .ascii) else { return [] }
        let sepBytes = [UInt8](sepData)
        let bytes = [UInt8](data)
        guard sepBytes.count <= bytes.count else { return [] }

        var positions: [Int] = []
        var i = 0
        let end = bytes.count - sepBytes.count
        while i <= end {
            let atLineStart = (i == 0) ||
                              (bytes[i - 1] == 0x0A)
            if atLineStart {
                var match = true
                for j in 0..<sepBytes.count {
                    if bytes[i + j] != sepBytes[j] { match = false; break }
                }
                if match {
                    positions.append(i)
                    i += sepBytes.count
                    continue
                }
            }
            i += 1
        }

        if positions.count < 2 { return [] }

        var parts: [Data] = []
        for idx in 0..<(positions.count - 1) {
            var start = positions[idx] + sepBytes.count
            if start < bytes.count, bytes[start] == 0x0D { start += 1 }
            if start < bytes.count, bytes[start] == 0x0A { start += 1 }

            var stop = positions[idx + 1]
            if stop > 0, bytes[stop - 1] == 0x0A { stop -= 1 }
            if stop > 0, bytes[stop - 1] == 0x0D { stop -= 1 }

            if stop > start {
                parts.append(Data(bytes[start..<stop]))
            } else {
                parts.append(Data())
            }
        }
        return parts
    }

    private static func range(of needle: [UInt8], in data: Data) -> Range<Int>? {
        guard !needle.isEmpty, needle.count <= data.count else { return nil }
        let base = data.startIndex
        let limit = data.count - needle.count
        for i in 0...limit {
            var match = true
            for j in 0..<needle.count {
                if data[base + i + j] != needle[j] { match = false; break }
            }
            if match {
                return (base + i)..<(base + i + needle.count)
            }
        }
        return nil
    }
}
