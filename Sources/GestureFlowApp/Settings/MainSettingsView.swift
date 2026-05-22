import SwiftUI
import GestureFlowCore

struct MainSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedSection: SettingsSection = .general
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 920, minHeight: 620)
        .background(backgroundGradient)
    }

    private var sidebarContent: some View {
        List(selection: $selectedSection) {
            ForEach(SettingsSection.allCases) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
        .toolbar(removing: .sidebarToggle)
        .scrollContentBackground(.hidden)
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let recoveryNoticeMessage = viewModel.recoveryNoticeMessage {
                recoveryBanner(message: recoveryNoticeMessage, backupPath: viewModel.recoveryBackupPath)
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
            }

            if let saveErrorMessage = viewModel.saveErrorMessage {
                saveErrorBanner(message: saveErrorMessage)
                    .padding(.horizontal, 28)
                    .padding(.top, recoveryNoticeMessagePadding)
            }

            currentSectionView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
    }

    @ViewBuilder
    private var currentSectionView: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsView(viewModel: viewModel)
        case .appearance:
            AppearanceSettingsView(viewModel: viewModel)
        case .gestures:
            SettingsPage {
                GestureListView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .about:
            AboutSettingsView()
        }
    }

    private var recoveryNoticeMessagePadding: CGFloat {
        viewModel.recoveryNoticeMessage == nil ? 20 : 12
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor).opacity(0.92),
                Color(nsColor: .windowBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func recoveryBanner(message: String, backupPath: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Configuration Recovery")
                .font(.headline)
            Text(message)
                .font(.caption)
            if let backupPath {
                Text(backupPath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private func saveErrorBanner(message: String) -> some View {
        Text("Failed to save settings: \(message)")
            .foregroundColor(.red)
            .font(.caption)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
