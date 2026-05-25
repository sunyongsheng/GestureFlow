import AppKit
import SwiftUI
import GestureFlowCore

struct GestureSignaturePicker: View {
    @Binding var selection: GestureSignature
    @State private var isPopoverPresented = false

    private let columnCount = 5
    private let columnWidth: CGFloat = 34
    private let columnSpacing: CGFloat = 6

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(columnWidth), spacing: columnSpacing), count: columnCount)
    }

    private var gridWidth: CGFloat {
        CGFloat(columnCount) * columnWidth + CGFloat(columnCount - 1) * columnSpacing
    }

    var body: some View {
        Button {
            isPopoverPresented = true
        } label: {
            HStack(spacing: 4) {
                previewImage(for: selection)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selection.chineseDisplayName)
        .help(selection.chineseDisplayName)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            signatureSelectionGrid
        }
    }

    private var signatureSelectionGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: columnSpacing) {
                ForEach(GestureSignatureCatalog.all) { option in
                    GestureSignaturePopoverCell(
                        option: option,
                        isSelected: selection == option.signature,
                        onSelect: {
                            selection = option.signature
                            isPopoverPresented = false
                        }
                    )
                }
            }
            .frame(width: gridWidth)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(NarrowVerticalScrollBarConfigurator())
        }
        .narrowVerticalScrollBar()
        .frame(width: gridWidth + 24, height: 280)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func previewImage(for signature: GestureSignature, size: CGSize) -> some View {
        GestureSignatureGlyphRenderer.image(for: signature, size: size)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .frame(width: size.width, height: size.height)
    }

    private func previewImage(for signature: GestureSignature) -> some View {
        previewImage(for: signature, size: GestureSignatureGlyphRenderer.listSize)
    }
}

private struct GestureSignaturePopoverCell: View {
    let option: GestureSignatureOption
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    private let glyphSize = GestureSignatureGlyphRenderer.popoverSize

    var body: some View {
        preview
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
            .scaleEffect(isHovered ? 1.12 : 1)
            .animation(.easeOut(duration: 0.14), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture(perform: onSelect)
            .help(option.displayName)
            .accessibilityLabel(option.displayName)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var preview: some View {
        GestureSignatureGlyphRenderer.image(for: option.signature, size: glyphSize)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .frame(width: glyphSize.width, height: glyphSize.height)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(isHovered ? 0.22 : 0.16)
        }
        if isHovered {
            return Color(nsColor: .quaternarySystemFill)
        }
        return Color(nsColor: .windowBackgroundColor)
    }
}

private extension View {
    func narrowVerticalScrollBar() -> some View {
        background(NarrowVerticalScrollBarConfigurator())
    }
}

private struct NarrowVerticalScrollBarConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NarrowVerticalScrollBarConfiguratorView {
        NarrowVerticalScrollBarConfiguratorView()
    }

    func updateNSView(_ nsView: NarrowVerticalScrollBarConfiguratorView, context: Context) {
        nsView.applyIfNeeded()
    }
}

private final class NarrowVerticalScrollBarConfiguratorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyIfNeeded()
    }

    override func layout() {
        super.layout()
        applyIfNeeded()
    }

    func applyIfNeeded() {
        guard let scrollView = enclosingScrollView else { return }

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.verticalScroller?.controlSize = .mini
    }
}
