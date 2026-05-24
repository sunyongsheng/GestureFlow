import AppKit
import SwiftUI

struct GestureEditingCommitMonitor: NSViewRepresentable {
    let onCommit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> GestureEditingMonitorView {
        let view = GestureEditingMonitorView()
        context.coordinator.attach(rootView: view, onCommit: onCommit)
        return view
    }

    func updateNSView(_ nsView: GestureEditingMonitorView, context: Context) {
        context.coordinator.attach(rootView: nsView, onCommit: onCommit)
    }

    final class Coordinator {
        private weak var rootView: NSView?
        private var onCommit: (() -> Void)?
        private var monitor: Any?

        func attach(rootView: NSView, onCommit: @escaping () -> Void) {
            self.rootView = rootView
            self.onCommit = onCommit
            installMonitorIfNeeded()
        }

        private func installMonitorIfNeeded() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self, let rootView = self.rootView, let window = rootView.window else {
                    return event
                }

                let location = window.mouseLocationOutsideOfEventStream
                let hitView = window.contentView?.hitTest(location)
                if self.isHit(hitView, inside: rootView) == false {
                    self.onCommit?()
                }
                return event
            }
        }

        private func isHit(_ view: NSView?, inside rootView: NSView) -> Bool {
            var current: NSView? = view
            while let currentView = current {
                if currentView === rootView {
                    return true
                }
                current = currentView.superview
            }
            return false
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

final class GestureEditingMonitorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
