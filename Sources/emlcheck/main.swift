import Foundation
import EMLCore

func printTree(_ p: Part, level: Int) {
    let pad = String(repeating: "  ", count: level)
    if p.isMultipart {
        let b = p.boundary ?? "?"
        print("\(pad)- \(p.contentType) boundary=\(b) (\(p.parts.count) parts)")
    } else {
        let size = p.body.count
        var info = "\(p.contentType) cte=\(p.encoding) body=\(size)B"
        if let n = p.filename { info += " name=\"\(n)\"" }
        if let c = p.contentID { info += " cid=\(c)" }
        if let d = p.disposition { info += " disp=\(d)" }
        if let cs = p.charset { info += " charset=\(cs)" }
        print("\(pad)- \(info)")
    }
    for sub in p.parts { printTree(sub, level: level + 1) }
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("Usage: emlcheck <file.eml>\n".utf8))
    exit(1)
}

let url = URL(fileURLWithPath: args[1])
do {
    let msg = try Message(url: url)

    print("=== Headers ===")
    print("From:    \(msg.from)")
    print("To:      \(msg.to)")
    if !msg.cc.isEmpty { print("CC:      \(msg.cc)") }
    if !msg.replyTo.isEmpty { print("ReplyTo: \(msg.replyTo)") }
    print("Subject: \(msg.subject)")
    print("Date:    \(msg.date)")

    print("\n=== MIME tree ===")
    printTree(msg.root, level: 0)

    print("\n=== Bodies ===")
    if let plain = msg.plainBody { print("text/plain: \(plain.count) chars") }
    if let html  = msg.htmlBody { print("text/html:  \(html.count) chars") }

    let inlines = msg.inlineParts
    print("\n=== Inline (\(inlines.count)) ===")
    for p in inlines {
        let cid = p.contentID ?? "?"
        let name = p.filename ?? "-"
        print("  cid=\(cid)  \(p.contentType)  \(name)  \(p.decodedBody().count)B")
    }

    let atts = msg.attachments
    print("\n=== Attachments (\(atts.count)) ===")
    for p in atts {
        let name = p.filename ?? "-"
        print("  \(name)  \(p.contentType)  \(p.decodedBody().count)B")
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
