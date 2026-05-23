import SwiftUI
import GestureFlowCore

struct GestureEditorView: View {
    @Binding var gesture: GestureDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("启用", isOn: $gesture.isEnabled)
                .toggleStyle(.switch)

            TextField("名称", text: $gesture.name)
                .textFieldStyle(.roundedBorder)

            Picker("触发键", selection: $gesture.trigger) {
                Text("右键").tag(GestureTrigger.rightMouse)
                Text("中键").tag(GestureTrigger.middleMouse)
            }

            Picker("手势方向", selection: $gesture.signature) {
                ForEach(PresetSignature.all) { preset in
                    Text(preset.title).tag(preset.signature)
                }
            }

            Picker("执行动作", selection: actionChoiceBinding) {
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
        PresetSignature(title: "左", signature: GestureSignature(tokens: [.left])),
        PresetSignature(title: "右", signature: GestureSignature(tokens: [.right])),
        PresetSignature(title: "上", signature: GestureSignature(tokens: [.up])),
        PresetSignature(title: "下", signature: GestureSignature(tokens: [.down])),
        PresetSignature(title: "下、右", signature: GestureSignature(tokens: [.down, .right])),
        PresetSignature(title: "上、左", signature: GestureSignature(tokens: [.up, .left]))
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
            return "浏览器后退"
        case .browserForward:
            return "浏览器前进"
        case .showDesktop:
            return "显示桌面"
        case .lockScreen:
            return "锁定屏幕"
        case .openApple:
            return "打开 Apple 官网"
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
