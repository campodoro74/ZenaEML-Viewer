import XCTest
@testable import EMLCore

final class SampleFixtureTests: XCTestCase {

    private func loadSample() throws -> Message {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle(for: SampleFixtureTests.self)
#endif
        let url = try XCTUnwrap(
            bundle.url(forResource: "sample", withExtension: "eml", subdirectory: "Fixtures")
                ?? bundle.url(forResource: "sample", withExtension: "eml"),
            "sample.eml fixture must be bundled with tests"
        )
        return try Message(url: url)
    }

    func testHeadersParsed() throws {
        let msg = try loadSample()
        XCTAssertEqual(msg.from, "Alice Example <alice@example.com>")
        XCTAssertEqual(msg.to, "Bob Example <bob@example.com>")
        XCTAssertEqual(msg.cc, "Carol Example <carol@example.com>")
        XCTAssertEqual(msg.subject, "Café meetup on Friday")
        XCTAssertEqual(msg.date, "Fri, 10 Apr 2026 14:30:00 +0000")
    }

    func testPlainBodyDecoded() throws {
        let msg = try loadSample()
        let plain = try XCTUnwrap(msg.plainBody)
        XCTAssertTrue(plain.contains("Café Central"))
        XCTAssertTrue(plain.contains("Let\u{2019}s meet"))
    }

    func testHtmlBodyContainsCIDReference() throws {
        let msg = try loadSample()
        let html = try XCTUnwrap(msg.htmlBody)
        XCTAssertTrue(html.contains(#"cid:logo@example"#))
    }

    func testInlineImageResolvedByCID() throws {
        let msg = try loadSample()
        let part = try XCTUnwrap(msg.partByContentID("logo@example"))
        XCTAssertEqual(part.contentType, "image/png")
        XCTAssertEqual(part.filename, "logo.png")
        XCTAssertFalse(part.decodedBody().isEmpty)
    }

    func testPdfAttachmentPresent() throws {
        let msg = try loadSample()
        XCTAssertEqual(msg.attachments.count, 1)
        let pdf = try XCTUnwrap(msg.attachments.first)
        XCTAssertEqual(pdf.filename, "agenda.pdf")
        XCTAssertEqual(pdf.contentType, "application/pdf")
        let bytes = pdf.decodedBody()
        XCTAssertTrue(bytes.starts(with: Data("%PDF-".utf8)), "attachment must decode to valid PDF header")
    }
}
