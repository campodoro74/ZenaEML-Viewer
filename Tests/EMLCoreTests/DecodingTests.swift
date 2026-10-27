import XCTest
@testable import EMLCore

final class DecodingTests: XCTestCase {

    // MARK: - Quoted-Printable

    func testQuotedPrintableHexByte() {
        let input = Data("Caf=C3=A9".utf8)
        let decoded = Decoding.quotedPrintable(input)
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "Café")
    }

    func testQuotedPrintableSoftLineBreak_CRLF() {
        let input = Data("line one=\r\nline two".utf8)
        let decoded = Decoding.quotedPrintable(input)
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "line oneline two")
    }

    func testQuotedPrintableSoftLineBreak_LF() {
        let input = Data("line one=\nline two".utf8)
        let decoded = Decoding.quotedPrintable(input)
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "line oneline two")
    }

    func testQuotedPrintablePassesThroughRegularText() {
        let input = Data("hello world".utf8)
        let decoded = Decoding.quotedPrintable(input)
        XCTAssertEqual(decoded, input)
    }

    func testQuotedPrintableLowercaseHex() {
        let input = Data("=c3=a9".utf8)
        let decoded = Decoding.quotedPrintable(input)
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "é")
    }

    // MARK: - Base64

    func testBase64Basic() {
        let data = Decoding.base64("aGVsbG8=")
        XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
    }

    func testBase64StripsWhitespaceAndNewlines() {
        let data = Decoding.base64("aGVs\n bG8 =\r\n")
        XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
    }

    // MARK: - Charset → String

    func testStringUTF8() {
        let data = Data([0xC3, 0xA9])
        XCTAssertEqual(Decoding.string(from: data, charset: "utf-8"), "é")
    }

    func testStringWindows1252() {
        let data = Data([0x93, 0x94]) // smart quotes
        let s = Decoding.string(from: data, charset: "Windows-1252")
        XCTAssertEqual(s, "\u{201C}\u{201D}")
    }

    func testEncodingLookupKnownAliases() {
        XCTAssertEqual(Decoding.encoding(for: "UTF-8"), .utf8)
        XCTAssertEqual(Decoding.encoding(for: "windows-1252"), .windowsCP1252)
        XCTAssertEqual(Decoding.encoding(for: "iso-8859-1"), .isoLatin1)
    }

    // MARK: - RFC 2047 encoded-words

    func testEncodedWordBase64() {
        let decoded = Decoding.decodeEncodedWords("=?UTF-8?B?SGVsbG8gV29ybGQ=?=")
        XCTAssertEqual(decoded, "Hello World")
    }

    func testEncodedWordQEncoded() {
        let decoded = Decoding.decodeEncodedWords("=?UTF-8?Q?Caf=C3=A9?=")
        XCTAssertEqual(decoded, "Café")
    }

    func testEncodedWordQUnderscoreIsSpace() {
        let decoded = Decoding.decodeEncodedWords("=?UTF-8?Q?Hello_World?=")
        XCTAssertEqual(decoded, "Hello World")
    }

    func testEncodedWordAdjacentStripsWhitespace() {
        let input = "=?UTF-8?B?SGVsbG8=?= =?UTF-8?B?V29ybGQ=?="
        let decoded = Decoding.decodeEncodedWords(input)
        XCTAssertEqual(decoded, "HelloWorld")
    }

    func testEncodedWordWithPlainTextAround() {
        let input = "Re: =?UTF-8?Q?Caf=C3=A9?= meeting"
        let decoded = Decoding.decodeEncodedWords(input)
        XCTAssertEqual(decoded, "Re: Café meeting")
    }

    func testEncodedWordWindows1252() {
        let input = "=?Windows-1252?Q?=93hi=94?="
        let decoded = Decoding.decodeEncodedWords(input)
        XCTAssertEqual(decoded, "\u{201C}hi\u{201D}")
    }

    func testEncodedWordNoMatchesReturnsAsIs() {
        let input = "Plain subject"
        XCTAssertEqual(Decoding.decodeEncodedWords(input), "Plain subject")
    }
}
