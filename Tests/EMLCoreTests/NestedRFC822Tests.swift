import XCTest
@testable import EMLCore

final class NestedRFC822Tests: XCTestCase {

    /// Outer forward with empty text/plain + message/rfc822 carrying the real HTML —
    /// mirrors PEC / “Fwd: POSTA CERTIFICATA” shells.
    func testFindsHTMLInsideNestedRFC822() {
        let crlf = "\r\n"
        let inner = [
            "From: inner@example.com",
            "Subject: Inner subject",
            "MIME-Version: 1.0",
            "Content-Type: text/html; charset=utf-8",
            "",
            "<html><body><p>Inner HTML body</p></body></html>",
            "",
        ].joined(separator: crlf)

        let outer = [
            "From: outer@example.com",
            "Subject: Fwd: Inner subject",
            "MIME-Version: 1.0",
            "Content-Type: multipart/mixed; boundary=\"BOUND\"",
            "",
            "--BOUND",
            "Content-Type: text/plain; charset=utf-8",
            "Content-Disposition: inline",
            "",
            "",
            "--BOUND",
            "Content-Type: message/rfc822",
            "Content-Disposition: inline",
            "",
            inner + "--BOUND--",
            "",
        ].joined(separator: crlf)

        let message = Message(data: Data(outer.utf8))
        XCTAssertEqual(message.from, "outer@example.com")
        XCTAssertTrue(
            message.htmlBody?.contains("Inner HTML body") == true,
            "htmlBody=\(message.htmlBody ?? "nil")"
        )
    }

    func testNamedRFC822ListedAsAttachment() {
        let crlf = "\r\n"
        let inner = [
            "From: a@b.c",
            "Subject: Attached mail",
            "Content-Type: text/plain; charset=utf-8",
            "",
            "Hello from attachment",
            "",
        ].joined(separator: crlf)

        let outer = [
            "From: outer@example.com",
            "Subject: Has eml",
            "MIME-Version: 1.0",
            "Content-Type: multipart/mixed; boundary=\"B\"",
            "",
            "--B",
            "Content-Type: text/plain; charset=utf-8",
            "",
            "See attached.",
            "--B",
            "Content-Type: message/rfc822",
            "Content-Disposition: attachment; filename=\"postacert.eml\"",
            "",
            inner + "--B--",
            "",
        ].joined(separator: crlf)

        let message = Message(data: Data(outer.utf8))
        let names = message.attachments.compactMap(\.filename)
        XCTAssertTrue(names.contains("postacert.eml"), "attachments=\(names)")
        XCTAssertTrue(
            message.plainBody?.contains("See attached") == true
                || message.plainBody?.contains("Hello from attachment") == true,
            "plainBody=\(message.plainBody ?? "nil")"
        )
    }

    func testDesktopPECForwardFixtureIfPresent() throws {
        let desktop = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
        let matches = (try? FileManager.default.contentsOfDirectory(at: desktop, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix("Fwd_") && $0.pathExtension.lowercased() == "eml" }
            ?? []
        guard let url = matches.first(where: { $0.lastPathComponent.contains("POSTA CERTIFICATA") }) else {
            throw XCTSkip("Desktop PEC forward fixture not present")
        }
        let message = try Message(url: url)
        XCTAssertFalse(message.subject.isEmpty)
        let body = (message.htmlBody ?? message.plainBody ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(body.isEmpty, "Expected nested PEC body to be visible")
        XCTAssertTrue(
            message.attachments.contains {
                ($0.filename ?? "").lowercased().contains("postacert")
                    || MIME.isNestedMessage($0.contentType)
            },
            "Expected postacert.eml (or nested rfc822) in attachments"
        )
    }
}
