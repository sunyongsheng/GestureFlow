import AppKit
import SwiftUI
import GestureFlowCore

struct GestureSignaturePicker: View {
    @EnvironmentObject private var l10n: LocalizationManager
    @Binding var selection: GestureSignature
    @Binding var customGestureSignatures: [GestureSignature]
    let onPersistCustomSignatures: () -> Void
    let onPauseGestureRecognition: () -> Void
    let onResumeGestureRecognition: () -> Void

    @State private var isPopoverPresented = false
    @State private var isRecordingSheetPresented = false
    @State private var scrollTargetID: String?
    @State private var isAddCustomSignatureButtonHovered = false

    private let columnCount = 4
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
        .accessibilityLabel(l10n.localizedDisplayName(for: selection))
        .help(l10n.localizedDisplayName(for: selection))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            signatureSelectionGrid
        }
        .sheet(isPresented: $isRecordingSheetPresented) {
            GestureSignatureRecordingSheet(
                onConfirm: { signature in
                    handleRecordingConfirm(signature)
                },
                onCancel: {
                    isRecordingSheetPresented = false
                }
            )
        }
        .onChange(of: isRecordingSheetPresented) { isPresented in
            if isPresented {
                onPauseGestureRecognition()
            } else {
                onResumeGestureRecognition()
            }
        }
    }

    private var signatureSelectionGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: columns, spacing: columnSpacing) {
                        ForEach(GestureSignatureCatalog.all) { option in
                            builtInCell(option: option)
                                .id(option.id)
                        }
                    }

                    Divider()

                    LazyVGrid(columns: columns, spacing: columnSpacing) {
                        ForEach(customGestureSignatures, id: \.self) { signature in
                            customCell(signature: signature)
                                .id(GestureSignatureLookup.id(for: signature))
                        }
                        addCustomSignatureButton
                    }
                }
                .frame(width: gridWidth)
                .frame(maxWidth: .infinity)
                .padding(12)
            }
            .narrowVerticalScrollBar()
            .onChange(of: scrollTargetID) { targetID in
                guard let targetID else { return }
                withAnimation {
                    proxy.scrollTo(targetID, anchor: .center)
                }
                scrollTargetID = nil
            }
        }
        .frame(width: gridWidth + 24, height: 300)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func builtInCell(option: GestureSignatureOption) -> some View {
        GestureSignaturePopoverCell(
            signature: option.signature,
            displayName: l10n.localizedDisplayName(for: option.signature),
            isSelected: selection == option.signature,
            onSelect: {
                selection = option.signature
                isPopoverPresented = false
            }
        )
    }

    private func customCell(signature: GestureSignature) -> some View {
        GestureSignaturePopoverCell(
            signature: signature,
            displayName: l10n.localizedDisplayName(for: signature),
            isSelected: selection == signature,
            onSelect: {
                selection = signature
                isPopoverPresented = false
            }
        )
    }

    private var addCustomSignatureButton: some View {
        Image(systemName: "plus")
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(addCustomSignatureButtonBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .scaleEffect(isAddCustomSignatureButtonHovered ? 1.12 : 1)
            .animation(.easeOut(duration: 0.14), value: isAddCustomSignatureButtonHovered)
            .onHover { isAddCustomSignatureButtonHovered = $0 }
            .onTapGesture {
                isRecordingSheetPresented = true
            }
            .help(l10n.string(.gesturesDrawCustomSignatureHelp))
            .accessibilityLabel(l10n.string(.gesturesDrawCustomSignatureAccessibility))
            .accessibilityAddTraits(.isButton)
    }

    private var addCustomSignatureButtonBackground: Color {
        if isAddCustomSignatureButtonHovered {
            return Color(nsColor: .quaternarySystemFill)
        }
        return Color(nsColor: .windowBackgroundColor)
    }

    private func handleRecordingConfirm(_ signature: GestureSignature) {
        isRecordingSheetPresented = false

        if GestureSignatureLookup.exists(signature, customSignatures: customGestureSignatures) {
            selection = signature
            scrollTargetID = GestureSignatureLookup.id(for: signature)
            return
        }

        customGestureSignatures.append(signature)
        onPersistCustomSignatures()
        selection = signature
        scrollTargetID = GestureSignatureLookup.id(for: signature)
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
    let signature: GestureSignature
    let displayName: String
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
            .help(displayName)
            .accessibilityLabel(displayName)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var preview: some View {
        GestureSignatureGlyphRenderer.image(for: signature, size: glyphSize)
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
