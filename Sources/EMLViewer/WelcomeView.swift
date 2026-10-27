import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct WelcomeView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var prefsList: [AppPreferences]

    @State private var isDefault: Bool = false
    @State private var assocStatus: String?
    @State private var working: Bool = false

    private static let githubURLString = "https://github.com/campodoro74/ZenaEML-Viewer"
    private var githubURL: URL { URL(string: Self.githubURLString) ?? URL(fileURLWithPath: "/") }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 8)

            brandMark
                .frame(width: 72, height: 72)

            VStack(spacing: 4) {
                Text("ZenaEML Viewer")
                    .font(.system(size: 20, weight: .semibold))
                Text("by ZenaConsult")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Version \(appVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Viewer for .eml and .msg files · Finder Quick Look")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.horizontal, 60).padding(.vertical, 4)

            VStack(spacing: 12) {
                Button {
                    state.openPanel()
                } label: {
                    Label("Open .eml file…", systemImage: "folder")
                        .frame(width: 240)
                }
                .controlSize(.large)
                .keyboardShortcut("o")

                VStack(spacing: 6) {
                    associationRow
                    if let status = assocStatus {
                        Text(status)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                appearanceRow
            }

            if let err = state.errorText {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }

            Spacer(minLength: 8)

            footer
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: refreshAssociation)
    }

    // MARK: - Brand

    @ViewBuilder
    private var brandMark: some View {
        if let url = resourceBundle.url(forResource: "zena-logo", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Image(systemName: "envelope.open")
                .font(.system(size: 54, weight: .ultraLight))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Rows

    private var associationRow: some View {
        HStack(spacing: 8) {
            if isDefault {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Default for .eml and .msg files")
                    .font(.system(size: 12))
            } else {
                Button {
                    setAsDefault()
                } label: {
                    Label("Set as default for .eml and .msg", systemImage: "paperclip.badge.ellipsis")
                        .frame(width: 240)
                }
                .controlSize(.regular)
                .disabled(working)
            }
        }
    }

    private var appearanceRow: some View {
        HStack(spacing: 10) {
            Text("Appearance")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Picker("", selection: appearanceBinding) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    NSWorkspace.shared.open(githubURL)
                } label: {
                    HStack(spacing: 5) {
                        githubIconView
                        Text("GitHub")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                )
            }

            Text("ZenaConsult")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var githubIconView: some View {
        if let url = resourceBundle.url(forResource: "github", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .frame(width: 12, height: 12)
        } else {
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 11))
        }
    }

    private var resourceBundle: Bundle {
#if SWIFT_PACKAGE
        return Bundle.module
#else
        return Bundle.main
#endif
    }

    // MARK: - Bindings / state

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var supportedTypes: [UTType] {
        var types: [UTType] = []
        if let t = UTType(filenameExtension: "eml") ?? UTType("public.email-message") {
            types.append(t)
        }
        if let t = UTType(filenameExtension: "msg") ?? UTType("com.microsoft.outlook-email-message") {
            types.append(t)
        }
        return types
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { prefsList.first?.appearance ?? .system },
            set: { newValue in
                let prefs: AppPreferences
                if let existing = prefsList.first {
                    prefs = existing
                } else {
                    prefs = AppPreferences()
                    modelContext.insert(prefs)
                }
                prefs.appearance = newValue
                try? modelContext.save()
                newValue.save()
            }
        )
    }

    private func refreshAssociation() {
        guard let bundleID = Bundle.main.bundleIdentifier else { isDefault = false; return }
        let types = supportedTypes
        guard !types.isEmpty else { isDefault = false; return }

        for type in types {
            guard let handlerURL = NSWorkspace.shared.urlForApplication(toOpen: type),
                  let bundle = Bundle(url: handlerURL),
                  bundle.bundleIdentifier == bundleID else {
                isDefault = false
                return
            }
        }
        isDefault = true
    }

    private func setAsDefault() {
        let types = supportedTypes
        guard !types.isEmpty else {
            assocStatus = "UTType lookup failed"
            return
        }
        let appURL = Bundle.main.bundleURL
        working = true
        assocStatus = nil

        Task { @MainActor in
            var failure: Error?
            for type in types {
                do {
                    try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: type)
                } catch {
                    failure = error
                    break
                }
            }
            if let failure {
                assocStatus = "Could not set: \(failure.localizedDescription)"
            } else {
                assocStatus = "ZenaEML Viewer is now the default"
                refreshAssociation()
            }
            working = false
        }
    }
}
