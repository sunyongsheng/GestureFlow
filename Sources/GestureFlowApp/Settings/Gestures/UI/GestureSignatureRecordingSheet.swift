import SwiftUI
import GestureFlowCore

struct GestureSignatureRecordingSheet: View {
    let onConfirm: (GestureSignature) -> Void
    let onCancel: () -> Void

    @State private var recognizedSignature: GestureSignature?

    var body: some View {
        VStack(spacing: 16) {
            Text("绘制自定义手势")
                .font(.headline)

            GestureSignatureRecordingView(recognizedSignature: $recognizedSignature)

            HStack {
                Button("取消", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("确认") {
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
