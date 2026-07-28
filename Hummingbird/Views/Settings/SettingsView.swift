import SwiftUI

enum AppIconOption: String, CaseIterable, Identifiable {
    case classic
    case midnight
    case mono

    var id: String { rawValue }

    /// nil = primary (asset-catalog) icon.
    var alternateName: String? {
        switch self {
        case .classic: nil
        case .midnight: "Midnight"
        case .mono: "Mono"
        }
    }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .midnight: "Midnight"
        case .mono: "Mono"
        }
    }

    /// Bundle image used for the little preview swatch.
    var previewImageName: String {
        switch self {
        case .classic: "BrandMark"
        case .midnight: "AltIcon-Midnight"
        case .mono: "AltIcon-Mono"
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentAlternate = UIApplication.shared.alternateIconName

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("App Icon") {
                    ForEach(AppIconOption.allCases) { option in
                        Button {
                            setIcon(option)
                        } label: {
                            HStack(spacing: 14) {
                                preview(for: option)
                                Text(option.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if currentAlternate == option.alternateName {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .accessibilityLabel("\(option.title) app icon\(currentAlternate == option.alternateName ? ", selected" : "")")
                    }
                }

                Section {
                    LabeledContent("Version", value: version)
                } footer: {
                    Text("Hummingbird runs entirely on your device. Educational projections only — not financial advice.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder private func preview(for option: AppIconOption) -> some View {
        Group {
            if let ui = UIImage(named: option.previewImageName) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Image("BrandMark").resizable().scaledToFill()
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.quaternary))
        .accessibilityHidden(true)
    }

    private func setIcon(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(option.alternateName) { _ in
            currentAlternate = UIApplication.shared.alternateIconName
        }
    }
}
