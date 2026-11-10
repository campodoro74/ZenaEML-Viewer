import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import EMLCore

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var message: Message?
    @Published var sourceURL: URL?
    @Published var errorText: String?
    @Published var toast: String?
    @Published var language: AppLanguage = AppLanguage.load() {
        didSet {
            language.save()
            L10n.language = language.resolved
            objectWillChange.send()
        }
    }

    private init() {
        L10n.language = language.resolved
    }

    // MARK: - Loading

    func open(_ url: URL) {
        do {
            let msg = try Message(url: url)
            self.message = msg
            self.sourceURL = url
            self.errorText = nil
        } catch {
            self.errorText = L10n.t(.failedOpenPrefix) + error.localizedDescription
            self.message = nil
            self.sourceURL = url
        }
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let eml = UTType(filenameExtension: "eml") {
            panel.allowedContentTypes = [eml]
        }
        if panel.runModal() == .OK, let url = panel.url {
            open(url)
        }
    }

    // MARK: - Attachment actions

    func openAttachment(_ part: Part) {
        // Nested emails (message/rfc822 / *.eml): open in this window instead of
        // bouncing through Launch Services.
        let name = part.filename?.lowercased() ?? ""
        if MIME.isNestedMessage(part.contentType) || name.hasSuffix(".eml") || name.hasSuffix(".emlx") {
            let nested = Message(data: part.decodedBody())
            self.message = nested
            self.sourceURL = nil
            self.errorText = nil
            return
        }

        // FatturaPA XML → render PDF and open in Preview (not Xcode / XML editor).
        let data = part.decodedBody()
        if FatturaPA.isFatturaElettronica(data) {
            openFatturaPDF(FatturaInvoice(filename: part.filename ?? "fattura.xml", xmlData: data))
            return
        }

        guard let url = writeToTemp(part) else {
            NSSound.beep(); return
        }
        NSWorkspace.shared.open(url)
    }

    /// Build a temp PDF for a FatturaPA invoice and open it with Preview.
    func openFatturaPDF(_ invoice: FatturaInvoice) {
        toast = L10n.t(.openingInvoicePDF)
        let lang = language.resolved
        Task { @MainActor in
            do {
                let pdf = try await HTMLPDFExporter.pdfData(for: invoice, language: lang)
                let tmpDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("EMLViewer", isDirectory: true)
                try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
                let url = uniqueURL(in: tmpDir, filename: FatturaPA.suggestedPDFFilename(for: invoice))
                try pdf.write(to: url, options: .atomic)
                if let preview = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
                    try await NSWorkspace.shared.open(
                        [url],
                        withApplicationAt: preview,
                        configuration: NSWorkspace.OpenConfiguration()
                    )
                } else {
                    NSWorkspace.shared.open(url)
                }
                toast = nil
            } catch {
                toast = L10n.tf(.invoicePDFFailed, error.localizedDescription)
                NSSound.beep()
            }
        }
    }

    /// Open the raw attachment bytes with the system default app (e.g. XML in Xcode).
    func openAttachmentAsRawFile(_ part: Part) {
        guard let url = writeToTemp(part) else {
            NSSound.beep(); return
        }
        NSWorkspace.shared.open(url)
    }

    func saveAsAttachment(_ part: Part) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = part.filename ?? "attachment"
        if panel.runModal() == .OK, let url = panel.url {
            try? part.decodedBody().write(to: url)
        }
    }

    func downloadAll(_ attachments: [Part]) {
        guard !attachments.isEmpty else { return }
        let dir = downloadsDirectory()
        var saved: [URL] = []

        for part in attachments {
            let base = part.filename ?? "attachment"
            let target = uniqueURL(in: dir, filename: base)
            do {
                try part.decodedBody().write(to: target, options: .atomic)
                saved.append(target)
            } catch {
                continue
            }
        }

        if !saved.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(saved)
            let n = saved.count
            toast = L10n.tf(.savedFilesToDownloads, n, n == 1 ? "" : (L10n.language == .italian ? "" : "s"))
        }
    }

    // MARK: - Email PDF

    func exportMessagePDF() {
        guard let message else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = HTMLPDFExporter.suggestedEmailPDFFilename(
            for: message,
            sourceURL: sourceURL
        )
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let invoiceCount = FatturaPA.findInvoices(in: message).count
        toast = invoiceCount > 0 ? L10n.t(.creatingEmailInvoicePDF) : L10n.t(.creatingEmailPDF)
        let lang = language.resolved
        Task { @MainActor in
            do {
                let data = try await HTMLPDFExporter.pdfData(for: message, language: lang)
                try data.write(to: url, options: .atomic)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                toast = invoiceCount > 0 ? L10n.t(.emailInvoicePDFSaved) : L10n.t(.emailPDFSaved)
            } catch {
                toast = L10n.tf(.emailPDFFailed, error.localizedDescription)
                NSSound.beep()
            }
        }
    }

    // MARK: - FatturaPA invoice PDF

    /// Invoices found anywhere in the open message (including nested PEC shells).
    var invoices: [FatturaInvoice] {
        guard let message else { return [] }
        return FatturaPA.findInvoices(in: message)
    }

    func exportInvoicePDF(_ invoice: FatturaInvoice) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = FatturaPA.suggestedPDFFilename(for: invoice)
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        toast = L10n.t(.creatingInvoicePDF)
        let lang = language.resolved
        Task { @MainActor in
            do {
                let data = try await HTMLPDFExporter.pdfData(for: invoice, language: lang)
                try data.write(to: url, options: .atomic)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                toast = L10n.t(.invoicePDFSaved)
            } catch {
                toast = L10n.tf(.invoicePDFFailed, error.localizedDescription)
                NSSound.beep()
            }
        }
    }

    func exportAllInvoicePDFs() {
        let list = invoices
        guard !list.isEmpty else { return }
        if list.count == 1 {
            exportInvoicePDF(list[0])
            return
        }
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.prompt = L10n.t(.savePDFs)
            panel.message = L10n.tf(.chooseFolderInvoices, list.count)
            guard panel.runModal() == .OK, let dir = panel.url else { return }
            var saved: [URL] = []
            for invoice in list {
                do {
                    let data = try await HTMLPDFExporter.pdfData(for: invoice, language: language.resolved)
                    let target = uniqueURL(in: dir, filename: FatturaPA.suggestedPDFFilename(for: invoice))
                    try data.write(to: target, options: .atomic)
                    saved.append(target)
                } catch {
                    continue
                }
            }
            if !saved.isEmpty {
                NSWorkspace.shared.activateFileViewerSelecting(saved)
                toast = L10n.tf(.savedInvoicePDFs, saved.count, saved.count == 1 ? "" : (L10n.language == .italian ? "" : "s"))
            } else {
                toast = L10n.t(.noInvoicePDFs)
                NSSound.beep()
            }
        }
    }

    // MARK: - Helpers

    private func writeToTemp(_ part: Part) -> URL? {
        let base = part.filename ?? "attachment.bin"
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EMLViewer", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let url = uniqueURL(in: tmpDir, filename: base)
        do {
            try part.decodedBody().write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func downloadsDirectory() -> URL {
        if let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            return url
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    private func uniqueURL(in dir: URL, filename: String) -> URL {
        var candidate = dir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }

        let ns = filename as NSString
        let name = ns.deletingPathExtension
        let ext = ns.pathExtension
        var i = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let suffix = ext.isEmpty ? " (\(i))" : " (\(i)).\(ext)"
            candidate = dir.appendingPathComponent(name + suffix)
            i += 1
        }
        return candidate
    }
}
