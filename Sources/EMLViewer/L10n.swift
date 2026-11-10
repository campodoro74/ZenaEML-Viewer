import Foundation
import EMLCore

enum L10n {
    enum Key: String {
        // Welcome / chrome
        case byZenaConsult
        case tagline
        case aboutBlurb
        case howItWorks
        case openEml
        case appearance
        case language
        case languageSystem
        case appearanceSystem
        case appearanceLight
        case appearanceDark
        case defaultForFiles
        case setAsDefault
        case nowDefault
        case failedOpenPrefix

        // Convert / invoice bars
        case convertWithInvoice
        case convertInnermost
        case saveEmailPDF
        case saveInvoicePDF
        case saveAllInvoices
        case invoiceFoundOne
        case invoicesFoundMany

        // Headers
        case from
        case to
        case cc
        case date
        case noSubject
        case noBody
        case attachmentOne
        case attachmentsMany
        case downloadAll
        case saveAs

        // Menus
        case menuOpen
        case menuSaveEmailPDF
        case menuSaveInvoicePDF

        // Toasts
        case creatingEmailPDF
        case creatingEmailInvoicePDF
        case emailPDFSaved
        case emailInvoicePDFSaved
        case emailPDFFailed
        case creatingInvoicePDF
        case openingInvoicePDF
        case invoicePDFSaved
        case invoicePDFFailed
        case openAsPDF
        case openOriginalXML
        case savedFilesToDownloads
        case chooseFolderInvoices
        case savePDFs
        case savedInvoicePDFs
        case noInvoicePDFs
    }

    private static var table: [ContentLanguage: [Key: String]] {
        [
            .english: [
                .byZenaConsult: "by ZenaConsult",
                .tagline: "Open .eml / .msg · Convert to PDF · Finder Quick Look",
                .aboutBlurb: "Open saved .eml and .msg files offline — no Mail or Outlook needed. Preview headers, body, and attachments, then save a PDF.",
                .howItWorks: "Open a file → review the message → Save email PDF. Nested PEC forwards use the innermost email. Italian FatturaPA invoices are detected and can be appended or saved separately.",
                .openEml: "Open .eml file…",
                .appearance: "Appearance",
                .language: "Language",
                .languageSystem: "System",
                .appearanceSystem: "System",
                .appearanceLight: "Light",
                .appearanceDark: "Dark",
                .defaultForFiles: "Default for .eml and .msg files",
                .setAsDefault: "Set as default for .eml and .msg",
                .nowDefault: "ZenaEML Viewer to PDF is now the default",
                .failedOpenPrefix: "Failed to open: ",
                .convertWithInvoice: "PDF uses the innermost email and includes the invoice",
                .convertInnermost: "PDF uses the innermost nested email",
                .saveEmailPDF: "Save email PDF…",
                .saveInvoicePDF: "Save invoice PDF…",
                .saveAllInvoices: "Save all…",
                .invoiceFoundOne: "Italian e-invoice found (%@)",
                .invoicesFoundMany: "%d Italian e-invoices found",
                .from: "From",
                .to: "To",
                .cc: "Cc",
                .date: "Date",
                .noSubject: "(no subject)",
                .noBody: "(no body)",
                .attachmentOne: "1 attachment",
                .attachmentsMany: "%d attachments",
                .downloadAll: "Download All",
                .saveAs: "Save As…",
                .menuOpen: "Open…",
                .menuSaveEmailPDF: "Save email PDF…",
                .menuSaveInvoicePDF: "Save invoice PDF…",
                .creatingEmailPDF: "Creating PDF (innermost email)…",
                .creatingEmailInvoicePDF: "Creating PDF (innermost email + invoice)…",
                .emailPDFSaved: "Email PDF saved",
                .emailInvoicePDFSaved: "Email + invoice PDF saved",
                .emailPDFFailed: "Email PDF failed: %@",
                .creatingInvoicePDF: "Creating invoice PDF…",
                .openingInvoicePDF: "Opening invoice PDF…",
                .invoicePDFSaved: "Invoice PDF saved",
                .invoicePDFFailed: "Invoice PDF failed: %@",
                .openAsPDF: "Open as PDF",
                .openOriginalXML: "Open original XML…",
                .savedFilesToDownloads: "Saved %d file%@ to Downloads",
                .chooseFolderInvoices: "Choose a folder for %d invoice PDFs",
                .savePDFs: "Save PDFs",
                .savedInvoicePDFs: "Saved %d invoice PDF%@",
                .noInvoicePDFs: "No invoice PDFs could be saved",
            ],
            .italian: [
                .byZenaConsult: "di ZenaConsult",
                .tagline: "Apri .eml / .msg · Converti in PDF · Quick Look in Finder",
                .aboutBlurb: "Apri file .eml e .msg salvati offline — senza Mail o Outlook. Anteprima di intestazioni, corpo e allegati, poi salva un PDF.",
                .howItWorks: "Apri un file → controlla il messaggio → Salva PDF email. Nelle PEC annidate usa l’email più interna. Le fatture FatturaPA vengono rilevate e possono essere aggiunte al PDF o salvate a parte.",
                .openEml: "Apri file .eml…",
                .appearance: "Aspetto",
                .language: "Lingua",
                .languageSystem: "Sistema",
                .appearanceSystem: "Sistema",
                .appearanceLight: "Chiaro",
                .appearanceDark: "Scuro",
                .defaultForFiles: "Predefinita per file .eml e .msg",
                .setAsDefault: "Imposta come predefinita per .eml e .msg",
                .nowDefault: "ZenaEML Viewer to PDF è ora l’app predefinita",
                .failedOpenPrefix: "Apertura non riuscita: ",
                .convertWithInvoice: "Il PDF usa l’email più interna e include la fattura",
                .convertInnermost: "Il PDF usa l’email .eml più interna",
                .saveEmailPDF: "Salva PDF email…",
                .saveInvoicePDF: "Salva PDF fattura…",
                .saveAllInvoices: "Salva tutte…",
                .invoiceFoundOne: "Fattura elettronica trovata (%@)",
                .invoicesFoundMany: "%d fatture elettroniche trovate",
                .from: "Da",
                .to: "A",
                .cc: "Cc",
                .date: "Data",
                .noSubject: "(nessun oggetto)",
                .noBody: "(nessun corpo)",
                .attachmentOne: "1 allegato",
                .attachmentsMany: "%d allegati",
                .downloadAll: "Scarica tutti",
                .saveAs: "Salva con nome…",
                .menuOpen: "Apri…",
                .menuSaveEmailPDF: "Salva PDF email…",
                .menuSaveInvoicePDF: "Salva PDF fattura…",
                .creatingEmailPDF: "Creazione PDF (email più interna)…",
                .creatingEmailInvoicePDF: "Creazione PDF (email più interna + fattura)…",
                .emailPDFSaved: "PDF email salvato",
                .emailInvoicePDFSaved: "PDF email + fattura salvato",
                .emailPDFFailed: "PDF email non riuscito: %@",
                .creatingInvoicePDF: "Creazione PDF fattura…",
                .openingInvoicePDF: "Apertura PDF fattura…",
                .invoicePDFSaved: "PDF fattura salvato",
                .invoicePDFFailed: "PDF fattura non riuscito: %@",
                .openAsPDF: "Apri come PDF",
                .openOriginalXML: "Apri XML originale…",
                .savedFilesToDownloads: "Salvati %d file%@ in Download",
                .chooseFolderInvoices: "Scegli una cartella per %d PDF fattura",
                .savePDFs: "Salva PDF",
                .savedInvoicePDFs: "Salvati %d PDF fattura%@",
                .noInvoicePDFs: "Nessun PDF fattura salvato",
            ],
        ]
    }

    static var language: ContentLanguage = AppLanguage.load().resolved

    static func t(_ key: Key) -> String {
        table[language]?[key] ?? table[.english]?[key] ?? key.rawValue
    }

    static func tf(_ key: Key, _ args: CVarArg...) -> String {
        String(format: t(key), locale: Locale(identifier: language == .italian ? "it_IT" : "en_US"), arguments: args)
    }
}
