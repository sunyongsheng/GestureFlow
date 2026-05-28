import AppKit
import SwiftUI
import GestureFlowCore

struct MainSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var l10n: LocalizationManager
    @State private var selectedSection: SettingsSection = .general
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("")
        .toolbar(removing: .sidebarToggle)
        .frame(
            minWidth: SettingsWindowMetrics.minimumContentSize.width,
            minHeight: SettingsWindowMetrics.minimumContentSize.height
        )
    }

    private var sidebarContent: some View {
        List(selection: $selectedSection) {
            ForEach(SettingsSection.allCases) { section in
                Label(section.title(using: l10n), systemImage: section.symbolName)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .safeAreaPadding(.top)
        .navigationSplitViewColumnWidth(min: 140, ideal: 180, max: 240)
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
        .background(SettingsWindowChrome.detailBackground)
        .onChange(of: selectedSection) { _, _ in
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    @ViewBuilder
    private var currentSectionView: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsView(viewModel: viewModel)
        case .advanced:
            AdvancedSettingsView(viewModel: viewModel)
        case .gestures:
            GestureSettingsView(viewModel: viewModel)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
        case .about:
            AboutSettingsView()
        }
    }

    private var recoveryNoticeMessagePadding: CGFloat {
        viewModel.recoveryNoticeMessage == nil ? 20 : 12
    }

    private func recoveryBanner(message: String, backupPath: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.string(.settingsRecoveryTitle))
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
        Text(l10n.format(.settingsSaveFailed, message))
            .foregroundColor(.red)
            .font(.caption)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
