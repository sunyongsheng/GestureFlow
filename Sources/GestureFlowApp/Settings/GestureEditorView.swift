import SwiftUI
import GestureFlowCore

struct GestureEditorView: View {
    @Binding var gesture: GestureDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enabled", isOn: $gesture.isEnabled)
                .toggleStyle(.switch)

            TextField("Name", text: $gesture.name)
                .textFieldStyle(.roundedBorder)

            Picker("Trigger", selection: $gesture.trigger) {
                Text("Right Mouse").tag(GestureTrigger.rightMouse)
                Text("Middle Mouse").tag(GestureTrigger.middleMouse)
            }

            Picker("Signature", selection: $gesture.signature) {
                ForEach(PresetSignature.all) { preset in
                    Text(preset.title).tag(preset.signature)
                }
            }

            Picker("Action", selection: actionChoiceBinding) {
                ForEach(SimpleActionChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
        }
    }

    private var actionChoiceBinding: Binding<SimpleActionChoice> {
        Binding(
            get: { SimpleActionChoice(action: gesture.action) },
            set: { gesture.action = $0.action }
        )
    }
}

private struct PresetSignature: Identifiable {
    var id: String { title }
    var title: String
    var signature: GestureSignature

    static let all: [PresetSignature] = [
        PresetSignature(title: "Left", signature: GestureSignature(tokens: [.left])),
        PresetSignature(title: "Right", signature: GestureSignature(tokens: [.right])),
        PresetSignature(title: "Up", signature: GestureSignature(tokens: [.up])),
        PresetSignature(title: "Down", signature: GestureSignature(tokens: [.down])),
        PresetSignature(title: "Down, Right", signature: GestureSignature(tokens: [.down, .right])),
        PresetSignature(title: "Up, Left", signature: GestureSignature(tokens: [.up, .left]))
    ]
}

private enum SimpleActionChoice: String, CaseIterable, Identifiable {
    case browserBack
    case browserForward
    case showDesktop
    case lockScreen
    case openApple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browserBack:
            return "Browser Back"
        case .browserForward:
            return "Browser Forward"
        case .showDesktop:
            return "Show Desktop"
        case .lockScreen:
            return "Lock Screen"
        case .openApple:
            return "Open apple.com"
        }
    }

    var action: GestureAction {
        switch self {
        case .browserBack:
            return .keyboardShortcut(KeyboardShortcutAction(keyCode: 123, modifiers: [.command]))
        case .browserForward:
            return .keyboardShortcut(KeyboardShortcutAction(keyCode: 124, modifiers: [.command]))
        case .showDesktop:
            return .systemCommand(.showDesktop)
        case .lockScreen:
            return .systemCommand(.lockScreen)
        case .openApple:
            return .openURL(OpenURLAction(url: URL(string: "https://www.apple.com")!))
        }
    }

    init(action: GestureAction) {
        switch action {
        case .keyboardShortcut(let shortcut) where shortcut.keyCode == 123 && shortcut.modifiers == [.command]:
            self = .browserBack
        case .keyboardShortcut(let shortcut) where shortcut.keyCode == 124 && shortcut.modifiers == [.command]:
            self = .browserForward
        case .systemCommand(.showDesktop):
            self = .showDesktop
        case .systemCommand(.lockScreen):
            self = .lockScreen
        case .openURL:
            self = .openApple
        case .keyboardShortcut, .openApplication:
            self = .browserBack
        }
    }
}
