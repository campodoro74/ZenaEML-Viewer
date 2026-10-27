import XCTest
@testable import EMLCore

final class MIMETests: XCTestCase {

    // MARK: - parseStructuredHeader

    func testStructuredHeaderSimple() {
        let (main, params) = MIME.parseStructuredHeader("text/plain; charset=utf-8")
        XCTAssertEqual(main, "text/plain")
        XCTAssertEqual(params["charset"], "utf-8")
    }

    func testStructuredHeaderQuotedValue() {
        let (main, params) = MIME.parseStructuredHeader(#"attachment; filename="my file.pdf""#)
        XCTAssertEqual(main, "attachment")
        XCTAssertEqual(params["filename"], "my file.pdf")
    }

    func testStructuredHeaderMultipleParams() {
        let (main, params) = MIME.parseStructuredHeader(#"multipart/mixed; boundary="abc"; charset=us-ascii"#)
        XCTAssertEqual(main, "multipart/mixed")
        XCTAssertEqual(params["boundary"], "abc")
        XCTAssertEqual(params["charset"], "us-ascii")
    }

    func testStructuredHeaderSemicolonInsideQuotesNotSplitter() {
        let (_, params) = MIME.parseStructuredHeader(#"attachment; filename="weird;name.txt""#)
        XCTAssertEqual(params["filename"], "weird;name.txt")
    }

    func testStructuredHeaderRFC2231Continuation() {
        let header = #"attachment; filename*0="part-1-"; filename*1="part-2.txt""#
        let (_, params) = MIME.parseStructuredHeader(header)
        XCTAssertEqual(params["filename"], "part-1-part-2.txt")
    }

    func testStructuredHeaderRFC2231Encoded() {
        // UTF-8 encoded "Naïve.txt"
        let header = "attachment; filename*=UTF-8''Na%C3%AFve.txt"
        let (_, params) = MIME.parseStructuredHeader(header)
        XCTAssertEqual(params["filename"], "Naïve.txt")
    }

    // MARK: - Simple text/plain message

    func testSimpleTextPlain() {
        let raw = """
        Content-Type: text/plain; charset=utf-8\r
        \r
        Hello world
        """
        let part = MIME.parse(Data(raw.utf8))
        XCTAssertEqual(part.contentType, "text/plain")
        XCTAssertEqual(part.charset, "utf-8")
        XCTAssertFalse(part.isMultipart)
        XCTAssertEqual(part.decodedText(), "Hello world")
    }

    func testHeaderUnfolding() {
        let raw = """
        Subject: this is a very\r
         long subject line\r
        Content-Type: text/plain\r
        \r
        body
        """
        let part = MIME.parse(Data(raw.utf8))
        XCTAssertEqual(part.header("Subject"), "this is a very long subject line")
    }

    func testHeaderLookupIsCaseInsensitive() {
        let raw = "Content-Type: text/plain\r\n\r\nbody"
        let part = MIME.parse(Data(raw.utf8))
        XCTAssertNotNil(part.header("content-type"))
        XCTAssertNotNil(part.header("CONTENT-TYPE"))
    }

    // MARK: - Multipart

    func testMultipartAlternative() {
        let raw = """
        Content-Type: multipart/alternative; boundary="BDR"\r
        \r
        Preamble to be ignored\r
        --BDR\r
        Content-Type: text/plain\r
        \r
        plain body\r
        --BDR\r
        Content-Type: text/html\r
        \r
        <p>html body</p>\r
        --BDR--\r
        epilogue
        """
        let part = MIME.parse(Data(raw.utf8))
        XCTAssertTrue(part.isMultipart)
        XCTAssertEqual(part.contentType, "multipart/alternative")
        XCTAssertEqual(part.parts.count, 2)
        XCTAssertEqual(part.parts[0].contentType, "text/plain")
        XCTAssertEqual(part.parts[0].decodedText(), "plain body")
        XCTAssertEqual(part.parts[1].contentType, "text/html")
        XCTAssertEqual(part.parts[1].decodedText(), "<p>html body</p>")
    }

    func testNestedMultipart() {
        let raw = """
        Content-Type: multipart/mixed; boundary="OUT"\r
        \r
        --OUT\r
        Content-Type: multipart/alternative; boundary="IN"\r
        \r
        --IN\r
        Content-Type: text/plain\r
        \r
        plain\r
        --IN--\r
        --OUT\r
        Content-Type: application/octet-stream\r
        Content-Disposition: attachment; filename="file.bin"\r
        Content-Transfer-Encoding: base64\r
        \r
        aGVsbG8=\r
        --OUT--\r
        """
        let part = MIME.parse(Data(raw.utf8))
        XCTAssertEqual(part.parts.count, 2)
        XCTAssertTrue(part.parts[0].isMultipart)
        XCTAssertEqual(part.parts[0].parts.count, 1)
        XCTAssertEqual(part.parts[1].contentType, "application/octet-stream")
        XCTAssertEqual(part.parts[1].filename, "file.bin")
        XCTAssertEqual(String(data: part.parts[1].decodedBody(), encoding: .utf8), "hello")
    }

    // MARK: - Content-Transfer-Encoding

    func testBase64Body() {
        let raw = """
        Content-Type: text/plain\r
        Content-Transfer-Encoding: base64\r
        \r
        SGVsbG8gV29ybGQ=
        """
        let part = MIME.parse(Data(raw.utf8))
        XCTAssertEqual(part.encoding, "base64")
        XCTAssertEqual(String(data: part.decodedBody(), encoding: .utf8), "Hello World")
    }

    func testQuotedPrintableBody() {
        let raw = """
        Content-Type: text/plain; charset=utf-8\r
        Content-Transfer-Encoding: quoted-printable\r
        \r
        Caf=C3=A9 time
        """
        let part = MIME.parse(Data(raw.utf8))
        XCTAssertEqual(part.encoding, "quoted-printable")
        XCTAssertEqual(part.decodedText(), "Café time")
    }
}
