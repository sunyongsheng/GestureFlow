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

struct SettingsSliderRow<SliderView: View>: View {
    let title: String
    let valueText: String
    let rangeText: String
    @ViewBuilder let slider: SliderView

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
                Text(valueText)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                slider
                    .frame(width: 140)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Binding where Value == Double {
    /// Quantizes slider values without `Slider(step:)`, which draws tick marks on macOS.
    func snapping(to step: Double, in range: ClosedRange<Double>) -> Binding<Double> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                let clamped = Swift.min(Swift.max(newValue, range.lowerBound), range.upperBound)
                let quantized = (clamped / step).rounded() * step
                wrappedValue = Swift.min(Swift.max(quantized, range.lowerBound), range.upperBound)
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
