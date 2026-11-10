import XCTest
@testable import EMLCore

final class FatturaPATests: XCTestCase {

    private var fixturesBundle: Bundle {
#if SWIFT_PACKAGE
        Bundle.module
#else
        Bundle(for: FatturaPATests.self)
#endif
    }

    private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(
            fixturesBundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")
                ?? fixturesBundle.url(forResource: name, withExtension: ext),
            "\(name).\(ext) fixture missing"
        )
    }

    func testDetectsInvoiceXML() throws {
        let url = try fixtureURL("fattura-sample", "xml")
        let data = try Data(contentsOf: url)
        XCTAssertTrue(FatturaPA.isFatturaElettronica(data))
        let html = try FatturaPA.htmlDocument(xmlData: data)
        XCTAssertTrue(html.contains("AI Consulting"))
        XCTAssertTrue(html.contains("193/2026"))
        XCTAssertTrue(html.contains("219.60") || html.contains("39.60"))
    }

    func testFindsInvoiceInsideNestedPEC() throws {
        let url = try fixtureURL("pec-fattura-nested", "eml")
        let msg = try Message(url: url)
        let invoices = FatturaPA.findInvoices(in: msg)
        XCTAssertEqual(invoices.count, 1)
        XCTAssertEqual(invoices[0].filename, "IT01203670334_26193.xml")
        XCTAssertTrue(FatturaPA.isFatturaElettronica(invoices[0].xmlData))
        let suggested = FatturaPA.suggestedPDFFilename(for: invoices[0])
        XCTAssertTrue(suggested.lowercased().contains("193"), suggested)
        XCTAssertTrue(suggested.hasSuffix(".pdf"))
    }

    func testIgnoresMetadatiAndDaticert() throws {
        let url = try fixtureURL("pec-fattura-nested", "eml")
        let msg = try Message(url: url)
        let invoices = FatturaPA.findInvoices(in: msg)
        for inv in invoices {
            XCTAssertFalse(inv.filename.lowercased().contains("daticert"))
            XCTAssertFalse(inv.filename.lowercased().contains("_mt_"))
            let text = String(data: inv.xmlData, encoding: .utf8) ?? ""
            XCTAssertFalse(text.contains("FileMetadati"))
        }
    }

    func testInnermostMessageAndExportIncludesInvoice() throws {
        let url = try fixtureURL("pec-fattura-nested", "eml")
        let msg = try Message(url: url)
        let inner = msg.innermostMessage
        // Outer PEC subject starts with POSTA CERTIFICATA; innermost should be the SdI payload mail.
        XCTAssertNotEqual(inner.subject, msg.subject)
        XCTAssertFalse(inner.subject.uppercased().hasPrefix("POSTA CERTIFICATA: FWD:"), inner.subject)

        let html = PreviewHTML.buildSelfContained(from: msg)
        XCTAssertTrue(html.contains("invoice-page"), html.prefix(200).description)
        XCTAssertTrue(html.contains("AI Consulting") || html.contains("Fattura"), html.prefix(400).description)
        XCTAssertTrue(html.contains("193/2026") || html.contains("IT01203670334_26193.xml"))
    }
}
