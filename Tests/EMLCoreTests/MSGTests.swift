import XCTest
@testable import EMLCore

final class MSGTests: XCTestCase {

    private func loadSample() throws -> Message {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle(for: MSGTests.self)
#endif
        let url = try XCTUnwrap(
            bundle.url(forResource: "sample", withExtension: "msg", subdirectory: "Fixtures")
                ?? bundle.url(forResource: "sample", withExtension: "msg"),
            "sample.msg fixture must be bundled with tests"
        )
        return try Message(url: url)
    }

    func testDetectsCFBMagic() {
        let cfb = Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0x00, 0x00])
        XCTAssertTrue(MSG.isMSG(cfb))
        XCTAssertFalse(MSG.isMSG(Data("From: a@b\r\n".utf8)))
    }

    func testHeadersParsed() throws {
        let msg = try loadSample()
        XCTAssertEqual(msg.subject, "Test Outlook message with attachments")
        XCTAssertEqual(msg.from, "Alice Example <alice@example.com>")
        XCTAssertEqual(msg.to, "Bob Example <bob@example.com>")
        XCTAssertEqual(msg.cc, "Carol Example <carol@example.com>")
    }

    func testDateDecodedFromFiletime() throws {
        let msg = try loadSample()
        XCTAssertEqual(msg.date, "Thu, 16 Apr 2026 14:30:00 +0000")
    }

    func testPlainBodyDecoded() throws {
        let msg = try loadSample()
        let body = try XCTUnwrap(msg.plainBody)
        XCTAssertTrue(body.contains("synthetic Outlook .msg test fixture"))
    }

    func testHtmlBodyDecoded() throws {
        let msg = try loadSample()
        let html = try XCTUnwrap(msg.htmlBody)
        XCTAssertTrue(html.contains(#"cid:logo@example"#))
        XCTAssertTrue(html.contains("<strong>synthetic</strong>"))
    }

    func testAttachmentDecoded() throws {
        let msg = try loadSample()
        let atts = msg.attachments
        XCTAssertEqual(atts.count, 1)
        let pdf = try XCTUnwrap(atts.first)
        XCTAssertEqual(pdf.filename, "agenda.pdf")
        XCTAssertEqual(pdf.contentType, "application/pdf")
        XCTAssertTrue(pdf.decodedBody().starts(with: Data("%PDF-".utf8)))
    }

    func testInlineImageResolvedByCID() throws {
        let msg = try loadSample()
        let inline = try XCTUnwrap(msg.partByContentID("logo@example"))
        XCTAssertEqual(inline.filename, "logo.png")
        XCTAssertEqual(inline.contentType, "image/png")
        XCTAssertFalse(inline.decodedBody().isEmpty)
    }
}
