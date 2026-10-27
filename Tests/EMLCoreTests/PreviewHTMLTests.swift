import XCTest
@testable import EMLCore

final class PreviewHTMLTests: XCTestCase {
    func testBuildsHTMLWithHeadersAndPlainBody() throws {
        let raw = """
        From: Alice <alice@example.com>\r
        To: Bob <bob@example.com>\r
        Subject: Hello\r
        Date: Mon, 27 Oct 2025 10:00:00 +0100\r
        Content-Type: text/plain; charset=utf-8\r
        \r
        Hi Bob,\r
        This is a test.\r
        """
        let message = Message(data: Data(raw.utf8))
        let doc = PreviewHTML.build(from: message)
        XCTAssertTrue(doc.html.contains("Alice"))
        XCTAssertTrue(doc.html.contains("Hello"))
        XCTAssertTrue(doc.html.contains("Hi Bob"))
        XCTAssertTrue(doc.attachments.isEmpty)
    }

    func testRewritesCIDToAttachment() throws {
        let raw = """
        From: Alice <alice@example.com>
        Subject: Pic
        MIME-Version: 1.0
        Content-Type: multipart/related; boundary="BOUND"

        --BOUND
        Content-Type: text/html; charset=utf-8

        <html><body><img src="cid:img001@local"></body></html>
        --BOUND
        Content-Type: image/png
        Content-Transfer-Encoding: base64
        Content-ID: <img001@local>
        Content-Disposition: inline

        iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==
        --BOUND--
        """
        let message = Message(data: Data(raw.utf8))
        let doc = PreviewHTML.build(from: message)
        XCTAssertEqual(doc.attachments.count, 1)
        XCTAssertTrue(doc.html.contains(doc.attachments[0].id))
        XCTAssertFalse(doc.html.lowercased().contains("cid:img001"))
    }

    func testStripsScriptTags() throws {
        let raw = """
        From: Alice <alice@example.com>
        Subject: XSS
        Content-Type: text/html; charset=utf-8

        <html><body><script>alert(1)</script><p>Safe</p></body></html>
        """
        let message = Message(data: Data(raw.utf8))
        let doc = PreviewHTML.build(from: message)
        XCTAssertFalse(doc.html.lowercased().contains("<script"))
        XCTAssertTrue(doc.html.contains("Safe"))
    }
}
