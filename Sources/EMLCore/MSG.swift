import Foundation

public enum MSG {

    public static let magic: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]

    public static func isMSG(_ data: Data) -> Bool {
        guard data.count >= magic.count else { return false }
        for (i, b) in magic.enumerated() where data[data.startIndex + i] != b {
            return false
        }
        return true
    }

    public static func parse(_ data: Data) -> Part? {
        guard let cfb = CFB(data: data) else { return nil }

        guard let rootIndex = cfb.entries.firstIndex(where: { $0.type == 5 }) else { return nil }
        let rootChildren = cfb.children(of: rootIndex)

        var subject: String?
        var senderName: String?
        var senderEmail: String?
        var displayTo: String?
        var displayCc: String?
        var date: String?
        var plainBody: String?
        var htmlBody: String?
        var attachments: [AttachmentDraft] = []

        for idx in rootChildren {
            let entry = cfb.entries[idx]
            if entry.type == 2, entry.name.hasPrefix("__substg1.0_") {
                let (tag, type) = tagAndType(entry.name)
                let payload = cfb.read(entry)
                switch tag {
                case "0037": subject     = decodeString(payload, type: type)
                case "0C1A": senderName  = decodeString(payload, type: type)
                case "0C1F": senderEmail = decodeString(payload, type: type)
                case "0E04": displayTo   = decodeString(payload, type: type)
                case "0E03": displayCc   = decodeString(payload, type: type)
                case "0039": if type == "0040" { date = decodeFiletime(payload) }
                case "1000": plainBody = decodeString(payload, type: type)
                case "1013": htmlBody  = decodeHTML(payload, type: type)
                default: break
                }
            } else if entry.type == 1, entry.name.hasPrefix("__attach_version1.0_") {
                if let att = parseAttachment(cfb: cfb, storageIndex: idx) {
                    attachments.append(att)
                }
            }
        }

        return synthesizePart(
            subject: subject,
            senderName: senderName,
            senderEmail: senderEmail,
            displayTo: displayTo,
            displayCc: displayCc,
            date: date,
            plainBody: plainBody,
            htmlBody: htmlBody,
            attachments: attachments
        )
    }

    private struct AttachmentDraft {
        var filename: String
        var contentType: String
        var contentID: String?
        var data: Data
    }

    private static func parseAttachment(cfb: CFB, storageIndex: Int) -> AttachmentDraft? {
        var filename: String?
        var longFilename: String?
        var mime: String?
        var contentID: String?
        var data: Data?

        for idx in cfb.children(of: storageIndex) {
            let entry = cfb.entries[idx]
            guard entry.type == 2, entry.name.hasPrefix("__substg1.0_") else { continue }
            let (tag, type) = tagAndType(entry.name)
            let payload = cfb.read(entry)
            switch tag {
            case "3704": filename     = decodeString(payload, type: type)
            case "3707": longFilename = decodeString(payload, type: type)
            case "370E": mime         = decodeString(payload, type: type)
            case "3712":
                if let raw = decodeString(payload, type: type) {
                    contentID = raw.trimmingCharacters(in: CharacterSet(charactersIn: "<> \t\r\n"))
                }
            case "3701": if type == "0102" { data = payload }
            default: break
            }
        }

        guard let data else { return nil }
        let name = longFilename ?? filename ?? "attachment"
        let ctype = (mime?.isEmpty == false ? mime : nil) ?? guessContentType(filename: name)
        return AttachmentDraft(filename: name, contentType: ctype, contentID: contentID, data: data)
    }

    // MARK: - Decoders

    private static func tagAndType(_ streamName: String) -> (String, String) {
        let suffix = String(streamName.dropFirst("__substg1.0_".count))
        guard suffix.count == 8 else { return ("", "") }
        return (String(suffix.prefix(4)), String(suffix.suffix(4)))
    }

    private static func decodeString(_ data: Data, type: String) -> String? {
        switch type {
        case "001F":
            return String(data: data, encoding: .utf16LittleEndian)?
                .trimmingCharacters(in: .controlCharacters)
        case "001E":
            return String(data: data, encoding: .windowsCP1252) ?? String(data: data, encoding: .ascii)
        default:
            return nil
        }
    }

    private static func decodeHTML(_ data: Data, type: String) -> String? {
        switch type {
        case "0102":
            if let s = String(data: data, encoding: .utf8) { return s }
            if let s = String(data: data, encoding: .windowsCP1252) { return s }
            return String(data: data, encoding: .isoLatin1)
        case "001F":
            return String(data: data, encoding: .utf16LittleEndian)
        default:
            return nil
        }
    }

    private static func decodeFiletime(_ data: Data) -> String? {
        guard data.count >= 8 else { return nil }
        var ticks: UInt64 = 0
        for i in 0..<8 {
            ticks |= UInt64(data[data.startIndex + i]) << (8 * i)
        }
        let unixSeconds = Double(ticks) / 10_000_000 - 11_644_473_600
        let date = Date(timeIntervalSince1970: unixSeconds)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss '+0000'"
        return formatter.string(from: date)
    }

    private static func guessContentType(filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":  return "application/pdf"
        case "png":  return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif":  return "image/gif"
        case "txt":  return "text/plain"
        case "html", "htm": return "text/html"
        case "doc":  return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":  return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "zip":  return "application/zip"
        default:     return "application/octet-stream"
        }
    }

    private static func synthesizePart(
        subject: String?,
        senderName: String?,
        senderEmail: String?,
        displayTo: String?,
        displayCc: String?,
        date: String?,
        plainBody: String?,
        htmlBody: String?,
        attachments: [AttachmentDraft]
    ) -> Part {
        var headers: [(String, String)] = []
        if let subject { headers.append(("Subject", subject)) }

        let from = [senderName, senderEmail.map { "<\($0)>" }]
            .compactMap { $0 }
            .joined(separator: " ")
        if !from.isEmpty { headers.append(("From", from)) }
        if let displayTo, !displayTo.isEmpty { headers.append(("To", displayTo)) }
        if let displayCc, !displayCc.isEmpty { headers.append(("Cc", displayCc)) }
        if let date, !date.isEmpty { headers.append(("Date", date)) }

        let bodyPart = makeBodyPart(plain: plainBody, html: htmlBody)

        let inlines = attachments.filter { $0.contentID != nil }
        let downloads = attachments.filter { $0.contentID == nil }

        let contentRoot: Part = {
            if inlines.isEmpty { return bodyPart }
            var related = Part()
            related.rawHeaders = [("Content-Type", "multipart/related; boundary=\"related\"")]
            related.contentType = "multipart/related"
            related.contentTypeParams = ["boundary": "related"]
            related.parts = [bodyPart] + inlines.map(makeInlinePart)
            return related
        }()

        if downloads.isEmpty {
            var root = contentRoot
            root.rawHeaders = headers + root.rawHeaders
            return root
        }

        var root = Part()
        root.rawHeaders = headers + [("Content-Type", "multipart/mixed; boundary=\"mixed\"")]
        root.contentType = "multipart/mixed"
        root.contentTypeParams = ["boundary": "mixed"]
        root.parts = [contentRoot] + downloads.map(makeAttachmentPart)
        return root
    }

    private static func makeBodyPart(plain: String?, html: String?) -> Part {
        if let html {
            if let plain {
                var alt = Part()
                alt.rawHeaders = [("Content-Type", "multipart/alternative; boundary=\"alt\"")]
                alt.contentType = "multipart/alternative"
                alt.contentTypeParams = ["boundary": "alt"]
                alt.parts = [textPart(plain), htmlPart(html)]
                return alt
            }
            return htmlPart(html)
        }
        return textPart(plain ?? "")
    }

    private static func textPart(_ text: String) -> Part {
        var p = Part()
        p.rawHeaders = [("Content-Type", "text/plain; charset=utf-8")]
        p.contentType = "text/plain"
        p.contentTypeParams = ["charset": "utf-8"]
        p.body = Data(text.utf8)
        return p
    }

    private static func htmlPart(_ html: String) -> Part {
        var p = Part()
        p.rawHeaders = [("Content-Type", "text/html; charset=utf-8")]
        p.contentType = "text/html"
        p.contentTypeParams = ["charset": "utf-8"]
        p.body = Data(html.utf8)
        return p
    }

    private static func makeAttachmentPart(_ a: AttachmentDraft) -> Part {
        var p = Part()
        p.rawHeaders = [
            ("Content-Type", "\(a.contentType); name=\"\(a.filename)\""),
            ("Content-Disposition", "attachment; filename=\"\(a.filename)\""),
        ]
        p.contentType = a.contentType
        p.contentTypeParams = ["name": a.filename]
        p.disposition = "attachment"
        p.dispositionParams = ["filename": a.filename]
        p.body = a.data
        return p
    }

    private static func makeInlinePart(_ a: AttachmentDraft) -> Part {
        var p = Part()
        var hdrs: [(String, String)] = [
            ("Content-Type", "\(a.contentType); name=\"\(a.filename)\""),
            ("Content-Disposition", "inline; filename=\"\(a.filename)\""),
        ]
        if let cid = a.contentID { hdrs.append(("Content-ID", "<\(cid)>")) }
        p.rawHeaders = hdrs
        p.contentType = a.contentType
        p.contentTypeParams = ["name": a.filename]
        p.disposition = "inline"
        p.dispositionParams = ["filename": a.filename]
        p.contentID = a.contentID
        p.body = a.data
        return p
    }
}

struct CFB {
    struct Entry {
        let name: String
        let type: UInt8
        let leftSibling: UInt32
        let rightSibling: UInt32
        let child: UInt32
        let startSector: UInt32
        let size: UInt64
    }

    let entries: [Entry]
    private let data: Data
    private let sectorSize: Int
    private let miniSectorSize: Int
    private let miniCutoff: UInt32
    private let fatChain: [UInt32]
    private let miniFatChain: [UInt32]
    private let miniStreamData: Data

    init?(data: Data) {
        guard data.count >= 512,
              data[data.startIndex + 0] == 0xD0,
              data[data.startIndex + 1] == 0xCF,
              data[data.startIndex + 2] == 0x11,
              data[data.startIndex + 3] == 0xE0 else { return nil }

        self.data = data

        let sectorShift: UInt16     = CFB.readU16(data, at: 30)
        let miniSectorShift: UInt16 = CFB.readU16(data, at: 32)
        self.sectorSize     = 1 << Int(sectorShift)
        self.miniSectorSize = 1 << Int(miniSectorShift)
        self.miniCutoff     = CFB.readU32(data, at: 56)

        let dirFirst     = CFB.readU32(data, at: 48)
        let miniFatFirst = CFB.readU32(data, at: 60)

        var difat: [UInt32] = []
        for i in 0..<109 {
            difat.append(CFB.readU32(data, at: 76 + i * 4))
        }

        let fat = CFB.readFAT(data: data, sectorSize: sectorSize, difat: difat)
        self.fatChain = fat

        let miniFatBytes = CFB.readChain(fat: fat, startSector: miniFatFirst, sectorSize: sectorSize, data: data)
        self.miniFatChain = stride(from: 0, to: miniFatBytes.count, by: 4).map { i -> UInt32 in
            let base = miniFatBytes.startIndex + i
            return UInt32(miniFatBytes[base])
                 | (UInt32(miniFatBytes[base + 1]) << 8)
                 | (UInt32(miniFatBytes[base + 2]) << 16)
                 | (UInt32(miniFatBytes[base + 3]) << 24)
        }

        let dirData = CFB.readChain(fat: fat, startSector: dirFirst, sectorSize: sectorSize, data: data)
        self.entries = CFB.parseDirectory(dirData)

        if let root = entries.first, root.type == 5 {
            self.miniStreamData = CFB.readChain(fat: fat, startSector: root.startSector, sectorSize: sectorSize, data: data)
        } else {
            self.miniStreamData = Data()
        }
    }

    func read(_ entry: Entry) -> Data {
        if entry.size < UInt64(miniCutoff) {
            return CFB.readMiniChain(
                miniFat: miniFatChain,
                startSector: entry.startSector,
                miniSectorSize: miniSectorSize,
                miniStream: miniStreamData
            ).prefix(Int(entry.size))
        }
        return CFB.readChain(
            fat: fatChain,
            startSector: entry.startSector,
            sectorSize: sectorSize,
            data: data
        ).prefix(Int(entry.size))
    }

    /// All directory indices that are descendants of the given storage (via child/left/right tree).
    func children(of storageIndex: Int) -> [Int] {
        guard storageIndex < entries.count else { return [] }
        let root = entries[storageIndex].child
        guard root != 0xFFFFFFFF else { return [] }
        var out: [Int] = []
        var stack: [UInt32] = [root]
        var visited = Set<UInt32>()
        while let idx = stack.popLast() {
            guard idx != 0xFFFFFFFF, !visited.contains(idx), Int(idx) < entries.count else { continue }
            visited.insert(idx)
            out.append(Int(idx))
            let e = entries[Int(idx)]
            if e.leftSibling != 0xFFFFFFFF { stack.append(e.leftSibling) }
            if e.rightSibling != 0xFFFFFFFF { stack.append(e.rightSibling) }
        }
        return out
    }

    // MARK: - static helpers

    private static func readU16(_ data: Data, at offset: Int) -> UInt16 {
        let base = data.startIndex + offset
        return UInt16(data[base]) | (UInt16(data[base + 1]) << 8)
    }

    private static func readU32(_ data: Data, at offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        return UInt32(data[base])
             | (UInt32(data[base + 1]) << 8)
             | (UInt32(data[base + 2]) << 16)
             | (UInt32(data[base + 3]) << 24)
    }

    private static func readU64(_ data: Data, at offset: Int) -> UInt64 {
        let lo = UInt64(readU32(data, at: offset))
        let hi = UInt64(readU32(data, at: offset + 4))
        return lo | (hi << 32)
    }

    private static func sectorOffset(_ sector: UInt32, sectorSize: Int) -> Int {
        (Int(sector) + 1) * sectorSize
    }

    private static func readFAT(data: Data, sectorSize: Int, difat: [UInt32]) -> [UInt32] {
        var fat: [UInt32] = []
        let entriesPerSector = sectorSize / 4
        fat.reserveCapacity(difat.count * entriesPerSector)
        for fatSector in difat where fatSector < 0xFFFFFFF0 {
            let offset = sectorOffset(fatSector, sectorSize: sectorSize)
            guard offset + sectorSize <= data.count else { continue }
            for i in 0..<entriesPerSector {
                fat.append(readU32(data, at: offset + i * 4))
            }
        }
        return fat
    }

    private static func readChain(fat: [UInt32], startSector: UInt32, sectorSize: Int, data: Data) -> Data {
        var result = Data()
        var sector = startSector
        var visited = Set<UInt32>()
        while sector < 0xFFFFFFF0 {
            if visited.contains(sector) { break }
            visited.insert(sector)
            let offset = sectorOffset(sector, sectorSize: sectorSize)
            guard offset + sectorSize <= data.count else { break }
            result.append(data[offset..<(offset + sectorSize)])
            guard Int(sector) < fat.count else { break }
            sector = fat[Int(sector)]
        }
        return result
    }

    private static func readMiniChain(
        miniFat: [UInt32],
        startSector: UInt32,
        miniSectorSize: Int,
        miniStream: Data
    ) -> Data {
        var result = Data()
        var sector = startSector
        var visited = Set<UInt32>()
        while sector < 0xFFFFFFF0 {
            if visited.contains(sector) { break }
            visited.insert(sector)
            let offset = Int(sector) * miniSectorSize
            guard offset + miniSectorSize <= miniStream.count else { break }
            result.append(miniStream[(miniStream.startIndex + offset)..<(miniStream.startIndex + offset + miniSectorSize)])
            guard Int(sector) < miniFat.count else { break }
            sector = miniFat[Int(sector)]
        }
        return result
    }

    private static func parseDirectory(_ data: Data) -> [Entry] {
        var entries: [Entry] = []
        let entryCount = data.count / 128
        for i in 0..<entryCount {
            let base = data.startIndex + i * 128
            let nameLen = Int(UInt16(data[base + 64]) | (UInt16(data[base + 65]) << 8))
            let name: String
            if nameLen >= 2, nameLen <= 64 {
                let nameData = data.subdata(in: base..<(base + nameLen - 2))
                name = String(data: nameData, encoding: .utf16LittleEndian) ?? ""
            } else {
                name = ""
            }
            let type  = data[base + 66]
            let left  = readU32(data, at: base + 68 - data.startIndex)
            let right = readU32(data, at: base + 72 - data.startIndex)
            let child = readU32(data, at: base + 76 - data.startIndex)
            let start = readU32(data, at: base + 116 - data.startIndex)
            let size  = readU64(data, at: base + 120 - data.startIndex)
            entries.append(Entry(
                name: name,
                type: type,
                leftSibling: left,
                rightSibling: right,
                child: child,
                startSector: start,
                size: size
            ))
        }
        return entries
    }
}
