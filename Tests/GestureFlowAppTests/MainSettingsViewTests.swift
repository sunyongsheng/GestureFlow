import AppKit
import SwiftUI
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

@MainActor
final class MainSettingsViewTests: XCTestCase {
    func testMainSettingsViewUsesNavigationSplitView() {
        let view = MainSettingsView(viewModel: makeViewModel())

        XCTAssertTrue(
            String(describing: type(of: view.body)).contains("NavigationSplitView"),
            "Expected MainSettingsView to be built on NavigationSplitView"
        )
    }

    func testMainSettingsViewDeclaresSidebarColumnVisibilityState() {
        let view = MainSettingsView(viewModel: makeViewModel())
        let statePropertyNames = Mirror(reflecting: view).children.compactMap(\.label)

        XCTAssertTrue(statePropertyNames.contains("_columnVisibility"))
    }

    func testMainSettingsViewSidebarDoesNotRenderBrandingHeaderText() {
        let hostingView = NSHostingView(
            rootView: MainSettingsView(viewModel: makeViewModel())
                .frame(width: 900, height: 600)
        )
        hostingView.frame = CGRect(x: 0, y: 0, width: 900, height: 600)
        hostingView.layoutSubtreeIfNeeded()

        let renderedStrings = extractVisibleStrings(from: hostingView)

        XCTAssertFalse(renderedStrings.contains("GestureFlow"))
        XCTAssertFalse(renderedStrings.contains("设置"))
    }

    private func makeViewModel() -> SettingsViewModel {
        SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            gestureConfiguration: .defaultTemplate,
            isRunning: false,
            isAccessibilityTrusted: true,
            saveConfiguration: { _ in },
            saveGestureConfiguration: { _ in },
            requestAccessibilityPermission: {}
        )
    }

    private func extractVisibleStrings(from view: NSView) -> Set<String> {
        var strings: Set<String> = []
        collectVisibleStrings(from: view, into: &strings)
        return strings
    }

    private func collectVisibleStrings(from view: NSView, into strings: inout Set<String>) {
        if let textField = view as? NSTextField {
            let value = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                strings.insert(value)
            }
        }

        if let button = view as? NSButton {
            let title = button.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                strings.insert(title)
            }
        }

        for subview in view.subviews {
            collectVisibleStrings(from: subview, into: &strings)
        }
    }
}
