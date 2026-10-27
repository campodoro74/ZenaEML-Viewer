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

    private init() {}

    // MARK: - Loading

    func open(_ url: URL) {
        do {
            let msg = try Message(url: url)
            self.message = msg
            self.sourceURL = url
            self.errorText = nil
        } catch {
            self.errorText = "Failed to open: \(error.localizedDescription)"
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
            toast = "Saved \(n) file\(n == 1 ? "" : "s") to Downloads"
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
