import SwiftUI
import GestureFlowCore

struct GestureListView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gestures")
                .font(.headline)

            if viewModel.configuration.gestures.isEmpty {
                Text("No gestures configured.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.configuration.gestures) { gesture in
                            GestureEditorView(gesture: binding(for: gesture))
                                .padding(12)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    private func binding(for gesture: GestureDefinition) -> Binding<GestureDefinition> {
        Binding(
            get: {
                viewModel.configuration.gestures.first(where: { $0.id == gesture.id }) ?? gesture
            },
            set: { updatedGesture in
                viewModel.replaceGesture(updatedGesture)
            }
        )
    }
}
