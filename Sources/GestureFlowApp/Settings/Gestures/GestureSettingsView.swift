import SwiftUI
import GestureFlowCore

struct GestureSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var recordingGestureID: UUID?
    @State private var selectedGestureIDs = Set<GestureDefinition.ID>()
    @State private var nameEditDrafts: [UUID: String] = [:]
    @State private var editingGestureID: UUID?
    @State private var isRestoreDefaultsConfirmationPresented = false
    @FocusState private var focusedNameGestureID: UUID?

    var body: some View {
        HSplitView {
            applicationList
            gestureList
        }
    }

    private var applicationList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("应用")
                .font(.headline)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            List(selection: $viewModel.selectedApplicationScope) {
                Text("全局")
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tag(GestureApplicationScope.global)

                ForEach(viewModel.registeredApplicationBundleIdentifiers, id: \.self) { bundleIdentifier in
                    applicationScopeRow(
                        title: viewModel.displayName(for: bundleIdentifier),
                        bundleIdentifier: bundleIdentifier,
                        onDelete: {
                            viewModel.removeApplication(bundleIdentifier: bundleIdentifier)
                        }
                    )
                    .tag(GestureApplicationScope.application(bundleIdentifier: bundleIdentifier))
                }
            }
            .listStyle(.inset)

            Button {
                viewModel.addApplicationFromPanel()
            } label: {
                Label("添加应用", systemImage: "plus")
            }
        }
        .frame(minWidth: 120, idealWidth: 150, maxWidth: 260, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func applicationScopeRow(
        title: String,
        bundleIdentifier: String,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            ApplicationBundleIconView(bundleIdentifier: bundleIdentifier)

            Text(title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .help("删除应用及其手势")
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var gestureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(scopeTitle)
                    .font(.headline)

                Spacer()

                Button("恢复默认") {
                    commitEditingGestureIfNeeded(leaving: nil)
                    isRestoreDefaultsConfirmationPresented = true
                }

                Button {
                    commitEditingGestureIfNeeded(leaving: nil)
                    let newGestureID = viewModel.addGesture()
                    activateGestureEditing(newGestureID)
                    focusedNameGestureID = newGestureID
                } label: {
                    Image(systemName: "plus")
                        .frame(height: 12)
                }
                .help("新增手势")

                Button {
                    deleteSelectedGestures()
                } label: {
                    Image(systemName: "minus")
                        .frame(height: 12)
                }
                .help("删除选中的手势")
                .disabled(selectedGestureIDs.isEmpty)
            }
            .padding(.horizontal, 12)

            if let gestureSaveErrorMessage = viewModel.gestureSaveErrorMessage {
                Text(gestureSaveErrorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
            }

            VStack(spacing: 0) {
                gestureListHeader
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                Divider()

                List(scopedGestures, selection: $selectedGestureIDs) { gesture in
                    gestureListRow(for: gesture)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .layoutPriority(1)
        }
        .onChange(of: selectedGestureIDs) { _, _ in
            commitEditingGestureIfNeeded(leaving: selectedGestureIDs.first)
        }
        .onChange(of: viewModel.selectedApplicationScope) { _, _ in
            commitEditingGestureIfNeeded(leaving: nil)
            selectedGestureIDs.removeAll()
        }
        .onChange(of: focusedNameGestureID) { previousFocus, newFocus in
            if let previousFocus, previousFocus != newFocus {
                commitNameDraft(for: previousFocus)
            }
            if let newFocus {
                activateGestureEditing(newFocus)
                nameEditDrafts[newFocus] = gestureName(forGestureID: newFocus)
            }
        }
        .background {
            GestureEditingCommitMonitor {
                commitEditingGestureIfNeeded(leaving: nil)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .confirmationDialog(
            "恢复默认手势配置？",
            isPresented: $isRestoreDefaultsConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("恢复", role: .destructive) {
                resetGestureEditingState()
                viewModel.restoreDefaultGestureConfiguration()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将清除所有自定义应用与手势，仅保留内置的「关闭窗口」手势。")
        }
    }

    private func resetGestureEditingState() {
        editingGestureID = nil
        focusedNameGestureID = nil
        selectedGestureIDs.removeAll()
        nameEditDrafts.removeAll()
        recordingGestureID = nil
    }

    private var gestureListHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("名称")
                .frame(minWidth: 100, maxWidth: 140, alignment: .leading)
            Text("手势")
                .frame(width: 72, alignment: .leading)
            Text("触发")
                .frame(width: 80, alignment: .leading)
            Text("快捷键")
                .frame(minWidth: 96, maxWidth: 160, alignment: .leading)
            Text("启用")
                .frame(width: 44, alignment: .leading)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func gestureListRow(for gesture: GestureDefinition) -> some View {
        HStack(alignment: .center, spacing: 12) {
            nameCell(for: gesture)
                .frame(minWidth: 100, maxWidth: 140, alignment: .leading)

            signatureCell(for: gesture)
                .frame(width: 72, alignment: .leading)

            triggerCell(for: gesture)
                .frame(width: 80, alignment: .leading)

            shortcutCell(for: gesture)
                .frame(minWidth: 96, maxWidth: 160, alignment: .leading)

            Toggle(
                "",
                isOn: enabledBinding(for: gesture)
            )
            .labelsHidden()
            .frame(width: 44, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            activateGestureEditing(gesture.id)
        }
        .tag(gesture.id)
    }

    private var scopeTitle: String {
        switch viewModel.selectedApplicationScope {
        case .global:
            return "全局"
        case .application(let bundleIdentifier):
            return viewModel.displayName(for: bundleIdentifier)
        }
    }

    private var scopedGestures: [GestureDefinition] {
        viewModel.gestures(for: viewModel.selectedApplicationScope.targetBundleIdentifier)
    }

    private func nameCell(for gesture: GestureDefinition) -> some View {
        TextField("名称", text: nameDraftBinding(for: gesture))
            .textFieldStyle(.plain)
            .focused($focusedNameGestureID, equals: gesture.id)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onSubmit {
                commitNameDraft(for: gesture.id)
                viewModel.commitGesture(id: gesture.id)
                focusedNameGestureID = nil
                if editingGestureID == gesture.id {
                    editingGestureID = nil
                }
            }
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    activateGestureEditing(gesture.id)
                    nameEditDrafts[gesture.id] = gestureName(for: gesture)
                    focusedNameGestureID = gesture.id
                }
            )
    }

    private func nameDraftBinding(for gesture: GestureDefinition) -> Binding<String> {
        Binding(
            get: {
                if focusedNameGestureID == gesture.id {
                    return nameEditDrafts[gesture.id] ?? gestureName(for: gesture)
                }
                return gestureName(for: gesture)
            },
            set: { newValue in
                nameEditDrafts[gesture.id] = newValue
            }
        )
    }

    private func gestureName(for gesture: GestureDefinition) -> String {
        gestureName(forGestureID: gesture.id) ?? gesture.name
    }

    private func gestureName(forGestureID gestureID: UUID) -> String? {
        viewModel.gestureConfiguration.gestures.first(where: { $0.id == gestureID })?.name
    }

    private func signatureCell(for gesture: GestureDefinition) -> some View {
        GestureSignaturePicker(selection: signatureBinding(for: gesture))
            .frame(width: 72, alignment: .leading)
    }

    private func triggerCell(for gesture: GestureDefinition) -> some View {
        Picker("", selection: triggerBinding(for: gesture)) {
            Text("右键").tag(GestureTrigger.rightMouse)
            Text("中键").tag(GestureTrigger.middleMouse)
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    private func shortcutCell(for gesture: GestureDefinition) -> some View {
        ZStack {
            Button {
                activateGestureEditing(gesture.id)
                recordingGestureID = gesture.id
            } label: {
                GestureShortcutTagsView(
                    shortcut: gestureShortcut(for: gesture),
                    isRecording: recordingGestureID == gesture.id
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            GestureShortcutRecorder(
                isRecording: recordingGestureID == gesture.id,
                onCapture: { shortcut in
                    viewModel.stageGestureUpdate(id: gesture.id) { $0.shortcut = shortcut }
                    recordingGestureID = nil
                    viewModel.commitGesture(id: gesture.id)
                },
                onCancel: {
                    recordingGestureID = nil
                }
            )
            .frame(width: 0, height: 0)
        }
    }

    private func gestureShortcut(for gesture: GestureDefinition) -> KeyboardShortcutAction {
        viewModel.gestureConfiguration.gestures.first(where: { $0.id == gesture.id })?.shortcut
            ?? gesture.shortcut
    }

    private func commitNameDraft(for gestureID: UUID) {
        guard let gesture = viewModel.gestureConfiguration.gestures.first(where: { $0.id == gestureID }) else {
            nameEditDrafts.removeValue(forKey: gestureID)
            return
        }

        let draft = nameEditDrafts[gestureID] ?? gestureName(for: gesture)
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? gestureName(for: gesture) : trimmed

        if resolvedName != gestureName(for: gesture) {
            viewModel.stageGestureUpdate(id: gesture.id) { $0.name = resolvedName }
        }

        nameEditDrafts.removeValue(forKey: gestureID)
    }

    private func activateGestureEditing(_ gestureID: UUID) {
        commitEditingGestureIfNeeded(leaving: gestureID)
        editingGestureID = gestureID
        selectedGestureIDs = [gestureID]
    }

    private func commitEditingGestureIfNeeded(leaving nextGestureID: UUID?) {
        guard let editingGestureID, editingGestureID != nextGestureID else { return }

        commitNameDraft(for: editingGestureID)
        viewModel.commitGesture(id: editingGestureID)
        self.editingGestureID = nextGestureID
    }

    private func deleteSelectedGestures() {
        guard !selectedGestureIDs.isEmpty else { return }

        if let editingGestureID, selectedGestureIDs.contains(editingGestureID) {
            commitNameDraft(for: editingGestureID)
            self.editingGestureID = nil
        } else {
            commitEditingGestureIfNeeded(leaving: nil)
        }

        viewModel.deleteGestures(withIDs: selectedGestureIDs)
        selectedGestureIDs.removeAll()
    }

    private func signatureBinding(for gesture: GestureDefinition) -> Binding<GestureSignature> {
        Binding(
            get: {
                viewModel.gestureConfiguration.gestures.first(where: { $0.id == gesture.id })?.signature
                    ?? gesture.signature
            },
            set: { newValue in
                activateGestureEditing(gesture.id)
                viewModel.stageGestureUpdate(id: gesture.id) { $0.signature = newValue }
            }
        )
    }

    private func triggerBinding(for gesture: GestureDefinition) -> Binding<GestureTrigger> {
        Binding(
            get: {
                viewModel.gestureConfiguration.gestures.first(where: { $0.id == gesture.id })?.trigger
                    ?? gesture.trigger
            },
            set: { newValue in
                activateGestureEditing(gesture.id)
                viewModel.stageGestureUpdate(id: gesture.id) { $0.trigger = newValue }
            }
        )
    }

    private func enabledBinding(for gesture: GestureDefinition) -> Binding<Bool> {
        Binding(
            get: {
                viewModel.gestureConfiguration.gestures.first(where: { $0.id == gesture.id })?.isEnabled
                    ?? gesture.isEnabled
            },
            set: { newValue in
                activateGestureEditing(gesture.id)
                viewModel.stageGestureUpdate(id: gesture.id) { $0.isEnabled = newValue }
            }
        )
    }
}
