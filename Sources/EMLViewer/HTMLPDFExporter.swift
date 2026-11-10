import Foundation
import AppKit
import WebKit
import EMLCore

/// Renders HTML in an off-screen WKWebView and exports PDF data.
@MainActor
enum HTMLPDFExporter {

    static func pdfData(html: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            PDFRunner.run(html: html) { result in
                continuation.resume(with: result)
            }
        }
    }

    static func pdfData(for message: Message, language: ContentLanguage = .systemPreferred) async throws -> Data {
        let html = PreviewHTML.buildSelfContained(from: message, language: language)
        return try await pdfData(html: html)
    }

    static func pdfData(for invoice: FatturaInvoice, language: ContentLanguage = .systemPreferred) async throws -> Data {
        let html = try FatturaPA.htmlDocument(xmlData: invoice.xmlData, language: language)
        return try await pdfData(html: html)
    }

    static func suggestedEmailPDFFilename(for message: Message, sourceURL: URL?) -> String {
        let subject = message.innermostMessage.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        if !subject.isEmpty {
            let cleaned = subject
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ ."))
            let mapped = String(cleaned.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
                .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "._ "))
            let base = String(mapped.prefix(80))
            if !base.isEmpty { return base + ".pdf" }
        }
        if let sourceURL {
            return sourceURL.deletingPathExtension().lastPathComponent + ".pdf"
        }
        return "email.pdf"
    }
}

/// Keeps itself alive until PDF generation finishes. WKWebView's navigationDelegate
/// is weak, so a local runner would otherwise deallocate before `didFinish`.
@MainActor
private final class PDFRunner: NSObject, WKNavigationDelegate {
    private static var active: [PDFRunner] = []

    private let html: String
    private let completion: (Result<Data, Error>) -> Void
    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var finished = false
    private var timeoutItem: DispatchWorkItem?

    static func run(html: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let runner = PDFRunner(html: html, completion: completion)
        active.append(runner)
        runner.start()
    }

    private init(html: String, completion: @escaping (Result<Data, Error>) -> Void) {
        self.html = html
        self.completion = completion
    }

    private func start() {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 794, height: 1123), configuration: config)
        wv.navigationDelegate = self

        // Off-screen window so WebKit actually lays out / paints (needed for createPDF).
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 794, height: 1123),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = wv
        window.orderBack(nil)

        self.webView = wv
        self.hostWindow = window
        wv.loadHTMLString(html, baseURL: nil)

        let timeout = DispatchWorkItem { [weak self] in
            self?.finish(.failure(PDFExportError.timeout))
        }
        self.timeoutItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give layout a beat after load before snapshotting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            let config = WKPDFConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: 794, height: 1123)
            webView.createPDF(configuration: config) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let data):
                    self.finish(.success(data))
                case .failure(let error):
                    if let fallback = self.printFallback(webView: webView) {
                        self.finish(fallback)
                    } else {
                        self.finish(.failure(error))
                    }
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    private func printFallback(webView: WKWebView) -> Result<Data, Error>? {
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.paperSize = NSSize(width: 595.2, height: 841.8) // A4
        info.topMargin = 24
        info.bottomMargin = 24
        info.leftMargin = 24
        info.rightMargin = 24
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = false

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenaeml-pdf-\(UUID().uuidString).pdf")
        info.dictionary()[NSPrintInfo.AttributeKey.jobDisposition] = NSPrintInfo.JobDisposition.save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = tmp

        let op = webView.printOperation(with: info)
        op.showsPrintPanel = false
        op.showsProgressPanel = false
        let ok = op.run()
        if ok, let data = try? Data(contentsOf: tmp) {
            try? FileManager.default.removeItem(at: tmp)
            return .success(data)
        }
        return nil
    }

    private func finish(_ result: Result<Data, Error>) {
        guard !finished else { return }
        finished = true
        timeoutItem?.cancel()
        timeoutItem = nil
        webView?.navigationDelegate = nil
        webView = nil
        hostWindow?.contentView = nil
        hostWindow?.close()
        hostWindow = nil
        completion(result)
        Self.active.removeAll { $0 === self }
    }
}

private enum PDFExportError: LocalizedError {
    case timeout

    var errorDescription: String? {
        switch self {
        case .timeout: return "Timed out while creating the PDF"
        }
    }
}
