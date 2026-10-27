import Foundation
import QuickLookUI
import UniformTypeIdentifiers
import EMLCore

@objc(PreviewProvider)
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let message = try Message(url: request.fileURL)
        let document = PreviewHTML.build(from: message)
        guard let htmlData = document.html.data(using: .utf8) else {
            throw PreviewError.encodeFailed
        }

        let reply = QLPreviewReply(
            dataOfContentType: .html,
            contentSize: CGSize(width: 820, height: 1100)
        ) { replyToUpdate -> Data in
            replyToUpdate.stringEncoding = .utf8
            for attachment in document.attachments {
                replyToUpdate.attachments[attachment.id] = QLPreviewReplyAttachment(
                    data: attachment.data,
                    contentType: attachment.contentType
                )
            }
            return htmlData
        }
        return reply
    }
}

private enum PreviewError: LocalizedError {
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .encodeFailed:
            return "Could not encode HTML preview."
        }
    }
}
