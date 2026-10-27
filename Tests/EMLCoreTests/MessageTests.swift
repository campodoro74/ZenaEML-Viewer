import XCTest
@testable import EMLCore

final class MessageTests: XCTestCase {

    // MARK: - Builders

    private func eml(_ body: String) -> Data { Data(body.utf8) }

    private var sampleFullMessage: Data {
        let raw = """
        From: Alice <alice@example.com>\r
        To: Bob <bob@example.com>\r
        Cc: Carol <carol@example.com>\r
        Subject: =?UTF-8?Q?Caf=C3=A9_meetup?=\r
        Date: Wed, 25 Mar 2026 04:26:52 +0000\r
        Content-Type: multipart/mixed; boundary="OUT"\r
        \r
        --OUT\r
        Content-Type: multipart/related; boundary="MID"\r
        \r
        --MID\r
        Content-Type: multipart/alternative; boundary="IN"\r
        \r
        --IN\r
        Content-Type: text/plain; charset=utf-8\r
        Content-Transfer-Encoding: quoted-printable\r
        \r
        Plain Caf=C3=A9 body\r
        --IN\r
        Content-Type: text/html; charset=utf-8\r
        \r
        <p>html body <img src="cid:logo@ex"></p>\r
        --IN--\r
        --MID\r
        Content-Type: image/png; name="logo.png"\r
        Content-Disposition: inline; filename="logo.png"\r
        Content-ID: <logo@ex>\r
        Content-Transfer-Encoding: base64\r
        \r
        aGVsbG8=\r
        --MID--\r
        --OUT\r
        Content-Type: application/pdf; name="report.pdf"\r
        Content-Disposition: attachment; filename="report.pdf"\r
        Content-Transfer-Encoding: base64\r
        \r
        d29ybGQ=\r
        --OUT--\r
        """
        return Data(raw.utf8)
    }

    // MARK: - Header decoding

    func testFromToCcSubjectDate() {
        let msg = Message(data: sampleFullMessage)
        XCTAssertEqual(msg.from, "Alice <alice@example.com>")
        XCTAssertEqual(msg.to, "Bob <bob@example.com>")
        XCTAssertEqual(msg.cc, "Carol <carol@example.com>")
        XCTAssertEqual(msg.subject, "Café meetup")
        XCTAssertEqual(msg.date, "Wed, 25 Mar 2026 04:26:52 +0000")
    }

    // MARK: - Bodies

    func testPlainBodyReturnedDecoded() {
        let msg = Message(data: sampleFullMessage)
        XCTAssertEqual(msg.plainBody, "Plain Café body")
    }

    func testHtmlBodyReturnedAsIs() {
        let msg = Message(data: sampleFullMessage)
        XCTAssertEqual(msg.htmlBody, #"<p>html body <img src="cid:logo@ex"></p>"#)
    }

    // MARK: - Attachments / inlines

    func testAttachmentsContainsPdfNotInlineImage() {
        let msg = Message(data: sampleFullMessage)
        let atts = msg.attachments
        XCTAssertEqual(atts.count, 1)
        XCTAssertEqual(atts.first?.filename, "report.pdf")
        XCTAssertEqual(atts.first?.contentType, "application/pdf")
    }

    func testInlinePartsContainsImageNotAttachment() {
        let msg = Message(data: sampleFullMessage)
        let inlines = msg.inlineParts
        XCTAssertEqual(inlines.count, 1)
        XCTAssertEqual(inlines.first?.contentID, "logo@ex")
        XCTAssertEqual(inlines.first?.contentType, "image/png")
    }

    func testPartByContentID() {
        let msg = Message(data: sampleFullMessage)
        guard let part = msg.partByContentID("logo@ex") else {
            XCTFail("expected part for content-id logo@ex"); return
        }
        XCTAssertEqual(String(data: part.decodedBody(), encoding: .utf8), "hello")
    }

    func testPartByContentIDStripsAngleBrackets() {
        let msg = Message(data: sampleFullMessage)
        XCTAssertNotNil(msg.partByContentID("<logo@ex>"))
    }

    // MARK: - Edge cases

    func testMessageWithoutHtmlFallsBackToPlain() {
        let raw = """
        From: a@x\r
        To: b@x\r
        Subject: plain only\r
        Content-Type: text/plain; charset=utf-8\r
        \r
        body text
        """
        let msg = Message(data: eml(raw))
        XCTAssertEqual(msg.plainBody, "body text")
        XCTAssertNil(msg.htmlBody)
        XCTAssertEqual(msg.attachments.count, 0)
    }

    func testMissingHeadersAreEmptyStrings() {
        let raw = "Content-Type: text/plain\r\n\r\nbody"
        let msg = Message(data: eml(raw))
        XCTAssertEqual(msg.from, "")
        XCTAssertEqual(msg.subject, "")
    }
}
