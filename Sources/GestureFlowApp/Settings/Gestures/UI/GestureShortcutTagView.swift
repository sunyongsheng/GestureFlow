import SwiftUI
import GestureFlowCore

struct GestureShortcutTagView: View {
    enum Style {
        case recorded
        case placeholder
        case recording
    }

    let text: String
    var style: Style = .recorded

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .overlay {
                if style == .placeholder {
                    Capsule(style: .continuous)
                        .strokeBorder(borderColor, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
            }
            .clipShape(Capsule(style: .continuous))
    }

    private var foregroundColor: Color {
        switch style {
        case .recorded:
            return Color.primary
        case .placeholder:
            return Color.secondary
        case .recording:
            return Color.accentColor
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .recorded:
            return Color(nsColor: .quaternaryLabelColor).opacity(0.45)
        case .placeholder:
            return Color.clear
        case .recording:
            return Color.accentColor.opacity(0.14)
        }
    }

    private var borderColor: Color {
        Color.secondary.opacity(0.35)
    }
}

struct GestureShortcutTagsView: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let shortcut: KeyboardShortcutAction
    var isRecording: Bool = false

    var body: some View {
        if isRecording {
            GestureShortcutTagView(text: l10n.string(.shortcutRecording), style: .recording)
        } else if shortcut.isRecorded {
            GestureShortcutTagView(text: GestureShortcutFormatting.displayString(for: shortcut))
        } else {
            GestureShortcutTagView(text: l10n.string(.shortcutClickToRecord), style: .placeholder)
        }
    }
}
