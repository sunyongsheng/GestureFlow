import AppKit
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case advanced
    case gestures
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "通用"
        case .advanced:
            return "高级"
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
        case .advanced:
            return "slider.horizontal.3"
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
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String?
    let description: String?
    @ViewBuilder let content: Content

    private var showsHeader: Bool {
        title != nil || description != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsHeader {
                VStack(alignment: .leading, spacing: 4) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }

                    if let description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
            }

            content
                .padding(.horizontal, 18)
                .padding(.vertical, showsHeader ? 12 : 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct SettingsGroupedRows<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
    }
}

struct SettingsRowDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 10)
    }
}

struct SettingsSliderRow: View {
    let title: String
    let rangeText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let precision: Int
    var valueSuffix: String = ""
    var usesIntegerDisplay: Bool = false

    private var snappedValue: Binding<Double> {
        $value.snapping(to: step, in: range)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))

                Text(rangeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 148, alignment: .leading)

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                EditableSliderValueField(
                    value: snappedValue,
                    range: range,
                    step: step,
                    precision: precision,
                    suffix: valueSuffix,
                    usesIntegerDisplay: usesIntegerDisplay
                )

                Slider(value: snappedValue, in: range)
                    .frame(width: 140)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EditableSliderValueField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let precision: Int
    let suffix: String
    let usesIntegerDisplay: Bool

    @State private var isEditing = false
    @State private var draftText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        valueContent
            .frame(width: fieldContentWidth, alignment: .center)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .fixedSize(horizontal: true, vertical: false)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .help("点击输入数值")
            .onChange(of: isFocused) { _, focused in
                if !focused, isEditing {
                    commitDraft()
                }
            }
    }

    @ViewBuilder
    private var valueContent: some View {
        if isEditing {
            TextField("", text: $draftText)
                .textFieldStyle(.plain)
                .font(valueFont)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .focused($isFocused)
                .onSubmit(commitDraft)
        } else {
            Text(displayText)
                .font(valueFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .onTapGesture { beginEditing() }
        }
    }

    private var valueFont: Font {
        .subheadline.weight(.medium).monospacedDigit()
    }

    private var fieldContentWidth: CGFloat {
        let displayWidth = measuredWidth(for: displayText)
        guard isEditing else { return displayWidth }

        let sizingText = draftText.isEmpty ? editableDraftText(for: value) : draftText
        let draftWidth = measuredWidth(for: sizingText)
        let maxWidth = measuredWidth(for: rangeUpperBoundDisplayText)
        return min(max(draftWidth, displayWidth), maxWidth)
    }

    private var rangeUpperBoundDisplayText: String {
        SliderValueFormatting.displayText(
            for: range.upperBound,
            precision: precision,
            suffix: suffix,
            usesIntegerDisplay: usesIntegerDisplay
        )
    }

    private func measuredWidth(for text: String) -> CGFloat {
        let nsFont = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.preferredFont(forTextStyle: .subheadline).pointSize,
            weight: .medium
        )
        return ceil((text as NSString).size(withAttributes: [.font: nsFont]).width)
    }

    private var displayText: String {
        SliderValueFormatting.displayText(
            for: value,
            precision: precision,
            suffix: suffix,
            usesIntegerDisplay: usesIntegerDisplay
        )
    }

    private func beginEditing() {
        draftText = editableDraftText(for: value)
        isEditing = true
        isFocused = true
    }

    private func commitDraft() {
        defer {
            isEditing = false
            isFocused = false
        }

        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parsed = Double(trimmed) else {
            draftText = editableDraftText(for: value)
            return
        }

        value = SliderValueFormatting.quantized(parsed, step: step, in: range)
        draftText = editableDraftText(for: value)
    }

    private func editableDraftText(for value: Double) -> String {
        if usesIntegerDisplay {
            return String(Int(value.rounded()))
        }
        return String(format: "%.\(precision)f", value)
    }
}

private enum SliderValueFormatting {
    static func displayText(
        for value: Double,
        precision: Int,
        suffix: String,
        usesIntegerDisplay: Bool
    ) -> String {
        if usesIntegerDisplay {
            return "\(Int(value.rounded()))\(suffix)"
        }
        return String(format: "%.\(precision)f", value) + suffix
    }

    static func quantized(_ value: Double, step: Double, in range: ClosedRange<Double>) -> Double {
        let clamped = Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
        let quantized = (clamped / step).rounded() * step
        return Swift.min(Swift.max(quantized, range.lowerBound), range.upperBound)
    }
}

extension Binding where Value == Double {
    /// Quantizes slider values without `Slider(step:)`, which draws tick marks on macOS.
    func snapping(to step: Double, in range: ClosedRange<Double>) -> Binding<Double> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                wrappedValue = SliderValueFormatting.quantized(newValue, step: step, in: range)
            }
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
