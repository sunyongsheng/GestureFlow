import SwiftUI
import GestureFlowCore

struct GestureSignatureRecordingSheet: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let onConfirm: (GestureSignature) -> Void
    let onCancel: () -> Void

    @State private var recognizedSignature: GestureSignature?

    var body: some View {
        VStack(spacing: 16) {
            Text(l10n.string(.gesturesRecordingSheetTitle))
                .font(.headline)

            GestureSignatureRecordingView(recognizedSignature: $recognizedSignature)

            HStack {
                Button(l10n.string(.gesturesRecordingSheetCancel), role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(l10n.string(.gesturesRecordingSheetConfirm)) {
                    guard let recognizedSignature else { return }
                    onConfirm(recognizedSignature)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(recognizedSignature == nil)
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}
