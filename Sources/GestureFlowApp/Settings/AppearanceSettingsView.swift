import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        SettingsPage {
            VStack(alignment: .leading, spacing: 18) {
                GestureTriggerSettingsView(viewModel: viewModel)
                FeedbackSettingsView(viewModel: viewModel)
            }
        }
    }
}
