import AppKit
import GestureFlowCore
import SwiftUI

struct GestureShortcutRecorder: NSViewRepresentable {
    var isRecording: Bool
    var onCapture: (KeyboardShortcutAction) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.addSubview(context.coordinator.captureView)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isRecording = isRecording
        if isRecording {
            context.coordinator.startRecording()
        } else {
            context.coordinator.stopRecording()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator {
        let captureView = NSView(frame: .zero)
        var isRecording = false
        private var monitor: Any?

        private let onCapture: (KeyboardShortcutAction) -> Void
        private let onCancel: () -> Void

        init(
            onCapture: @escaping (KeyboardShortcutAction) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func startRecording() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                guard let self, self.isRecording else { return event }

                if event.keyCode == 53 {
                    self.onCancel()
                    return nil
                }

                if event.type == .keyDown,
                   let shortcut = GestureShortcutFormatting.captureShortcut(from: event) {
                    self.onCapture(shortcut)
                    return nil
                }

                return event
            }
        }

        func stopRecording() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            stopRecording()
        }
    }
}
