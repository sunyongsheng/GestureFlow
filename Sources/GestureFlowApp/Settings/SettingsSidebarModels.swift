import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case gestures
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "通用"
        case .appearance:
            return "界面"
        case .gestures:
            return "手势"
        case .about:
            return "关于"
        }
    }

    var symbolName: String {
        switch self {
        case .general:
            return "gearshape"
        case .appearance:
            return "paintbrush"
        case .gestures:
            return "hand.draw"
        case .about:
            return "info.circle"
        }
    }
}

struct SettingsPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String?
    let description: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if title != nil || description != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }

                    if let description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct SettingsValueRow<Control: View>: View {
    let title: String
    let description: String?
    let statusText: String?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))

                if let description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 16)

            if let statusText {
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            control
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
