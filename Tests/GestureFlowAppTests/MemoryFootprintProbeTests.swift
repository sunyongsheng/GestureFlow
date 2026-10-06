import AppKit
import SwiftUI
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

/// Opt-in diagnostic: `GESTUREFLOW_MEMORY_PROBE=1 swift test --filter MemoryFootprintProbeTests`.
/// Shows real overlay panels and a settings window on screen, and prints the process footprint around
/// them to find what drives GestureFlow's footprint peak.
final class MemoryFootprintProbeTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GESTUREFLOW_MEMORY_PROBE"] == "1",
            "Set GESTUREFLOW_MEMORY_PROBE=1 to run the memory footprint probe"
        )
    }

    func testOverlayGestureFootprint() {
        let screens = NSScreen.screens.map { screen in
            let pixels = screen.frame.width * screen.frame.height * screen.backingScaleFactor * screen.backingScaleFactor
            return "\(Int(screen.frame.width))x\(Int(screen.frame.height))@\(Int(screen.backingScaleFactor))x"
                + " (one RGBA buffer \(Self.megabytes(UInt64(pixels * 4))))"
        }
        print("PROBE screens: \(screens.joined(separator: ", "))")
        let overlayWindow = GestureOverlayWindow(localization: LocalizationManager(language: .zhHans))
        render(frames: 5)
        report("overlay created, before first gesture")

        autoreleasepool {
            let screenFrame = NSScreen.main?.frame ?? .zero
            let origin = GesturePoint(x: screenFrame.midX, y: screenFrame.midY)
            overlayWindow.beginGesture(at: origin, appearance: GestureTrailAppearance(feedback: .default))
            render(frames: 5)
            report("first gesture began, nothing drawn yet")
            overlayWindow.cancelGesture()
            render(frames: 5)
        }

        for liquidGlassEnabled in [false, true] {
            var feedback = FeedbackConfiguration.default
            feedback.feedbackCardLiquidGlassEnabled = liquidGlassEnabled
            let appearance = GestureTrailAppearance(feedback: feedback)
            for gesture in 1...3 {
                var largestDuringGesture: UInt64 = 0
                autoreleasepool {
                    let screenFrame = NSScreen.main?.frame ?? .zero
                    let start = GesturePoint(x: screenFrame.midX - 240, y: screenFrame.midY)
                    overlayWindow.beginGesture(at: start, appearance: appearance)
                    for index in 1...160 {
                        let point = GesturePoint(
                            x: start.x + Double(index) * 3,
                            y: start.y + sin(Double(index) / 12) * 120
                        )
                        overlayWindow.appendGesturePoint(point)
                        overlayWindow.updateLiveGesture(
                            at: point,
                            appearance: appearance,
                            feedback: LiveGestureOverlayFeedback(message: "测试手势", showsCard: true)
                        )
                        if index.isMultiple(of: 8) {
                            render()
                            largestDuringGesture = max(largestDuringGesture, MemoryFootprint.sample().current)
                        }
                    }
                    overlayWindow.completeGesture(with: .unmatched, at: start, hideAfter: 0.05)
                    render()
                    largestDuringGesture = max(largestDuringGesture, MemoryFootprint.sample().current)
                    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
                    render(frames: 5)
                }
                report(
                    "gesture \(gesture), liquid glass \(liquidGlassEnabled ? "on" : "off"), after hide",
                    largestDuring: largestDuringGesture
                )
            }
        }

        RunLoop.current.run(until: Date().addingTimeInterval(5))
        render(frames: 5)
        report("5 s idle after last gesture")
        withExtendedLifetime(overlayWindow) {}
    }

    func testSettingsWindowFootprint() {
        let localization = LocalizationManager(language: .zhHans)
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            gestureConfiguration: BuiltInGestureSeeds.factoryBuiltinConfiguration(),
            isRunning: false,
            isAccessibilityTrusted: true,
            saveConfiguration: { _ in },
            saveGestureConfiguration: { _ in },
            requestAccessibilityPermission: {},
            startGestureFlow: {},
            stopGestureFlow: {},
            quitApplication: {},
            pauseGestureRecognition: {},
            resumeGestureRecognition: {}
        )
        report("before settings window")

        var window: NSWindow?
        autoreleasepool {
            let hostingView = NSHostingView(
                rootView: AnyView(MainSettingsView(viewModel: viewModel).environmentObject(localization))
            )
            let settingsWindow = NSWindow(
                contentRect: NSRect(origin: .zero, size: SettingsWindowMetrics.defaultContentSize),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.contentView = hostingView
            settingsWindow.center()
            settingsWindow.orderFrontRegardless()
            window = settingsWindow
            render(frames: 20)
            report("settings window shown (general)")

            let sections: [(String, AnyView)] = [
                ("advanced", AnyView(AdvancedSettingsView(viewModel: viewModel).environmentObject(localization))),
                ("gestures", AnyView(GestureSettingsView(viewModel: viewModel).environmentObject(localization))),
                ("about", AnyView(AboutSettingsView(viewModel: viewModel).environmentObject(localization)))
            ]
            for (name, section) in sections {
                hostingView.rootView = section
                render(frames: 20)
                report("settings section \(name)")
            }
        }

        autoreleasepool {
            window?.close()
            window = nil
            render(frames: 10)
        }
        report("settings window closed")

        RunLoop.current.run(until: Date().addingTimeInterval(5))
        report("5 s idle after closing")
    }

    private func render(frames: Int = 1) {
        for _ in 0..<frames {
            for window in NSApplication.shared.windows where window.isVisible {
                window.displayIfNeeded()
            }
            CATransaction.flush()
            RunLoop.current.run(until: Date().addingTimeInterval(0.016))
        }
    }

    private func report(_ phase: String, largestDuring: UInt64? = nil) {
        let footprint = MemoryFootprint.sample()
        var line = "PROBE \(phase): footprint \(Self.megabytes(footprint.current)), peak \(Self.megabytes(footprint.peak))"
        if let largestDuring {
            line += ", largest while drawing \(Self.megabytes(largestDuring))"
        }
        print(line)
    }

    private static func megabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}

private struct MemoryFootprint {
    let current: UInt64
    let peak: UInt64

    static func sample() -> MemoryFootprint {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return MemoryFootprint(current: 0, peak: 0)
        }
        return MemoryFootprint(current: info.phys_footprint, peak: UInt64(info.ledger_phys_footprint_peak))
    }
}
