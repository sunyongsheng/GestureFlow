import SwiftUI
import GestureFlowCore

struct GestureSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var l10n: LocalizationManager
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
            Text(l10n.string(.gesturesApplicationsLabel))
                .font(.headline)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            List(selection: $viewModel.selectedApplicationScope) {
                Text(l10n.string(.gesturesGlobalScope))
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
                Label(l10n.string(.gesturesAddApplication), systemImage: "plus")
            }
        }
        .frame(minWidth: 120, idealWidth: 150, maxWidth: 260, maxHeight: .infinity, alignment: .topLeading)
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
            .help(l10n.string(.gesturesDeleteApplicationHelp))
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

                Button(l10n.string(.gesturesRestoreDefaults)) {
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
                .help(l10n.string(.gesturesAddGestureHelp))

                Button {
                    deleteSelectedGestures()
                } label: {
                    Image(systemName: "minus")
                        .frame(height: 12)
                }
                .help(l10n.string(.gesturesDeleteGestureHelp))
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
                nameEditDrafts[newFocus] = storedGestureName(forGestureID: newFocus)
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
            l10n.string(.gesturesRestoreDefaultsAlertTitle),
            isPresented: $isRestoreDefaultsConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(l10n.string(.gesturesRestoreDefaultsConfirm), role: .destructive) {
                resetGestureEditingState()
                viewModel.restoreDefaultGestureConfiguration()
            }
            Button(l10n.string(.settingsCancel), role: .cancel) {}
        } message: {
            Text(l10n.string(.gesturesRestoreDefaultsMessage))
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
            Text(l10n.string(.gesturesColumnName))
                .frame(minWidth: 100, maxWidth: 140, alignment: .leading)
            Text(l10n.string(.gesturesColumnSignature))
                .frame(width: 72, alignment: .leading)
            Text(l10n.string(.gesturesColumnTrigger))
                .frame(width: 80, alignment: .leading)
            Text(l10n.string(.gesturesColumnShortcut))
                .frame(minWidth: 96, maxWidth: 160, alignment: .leading)
            Text(l10n.string(.gesturesColumnEnabled))
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
            return l10n.string(.gesturesGlobalScope)
        case .application(let bundleIdentifier):
            return viewModel.displayName(for: bundleIdentifier)
        }
    }

    private var scopedGestures: [GestureDefinition] {
        viewModel.gestures(for: viewModel.selectedApplicationScope.targetBundleIdentifier)
    }

    private func nameCell(for gesture: GestureDefinition) -> some View {
        TextField(l10n.string(.gesturesNamePlaceholder), text: nameDraftBinding(for: gesture))
            .textFieldStyle(.plain)
            .focused($focusedNameGestureID, equals: gesture.id)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onSubmit {
                commitNameDraft(for: gesture.id)
                focusedNameGestureID = nil
                if editingGestureID == gesture.id {
                    editingGestureID = nil
                }
            }
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    activateGestureEditing(gesture.id)
                    nameEditDrafts[gesture.id] = storedGestureName(for: gesture)
                        ?? viewModel.localizedGestureName(gesture)
                    focusedNameGestureID = gesture.id
                }
            )
    }

    private func nameDraftBinding(for gesture: GestureDefinition) -> Binding<String> {
        Binding(
            get: {
                if focusedNameGestureID == gesture.id {
                    return nameEditDrafts[gesture.id]
                        ?? storedGestureName(for: gesture)
                        ?? viewModel.localizedGestureName(gesture)
                }
                return viewModel.localizedGestureName(gesture)
            },
            set: { newValue in
                nameEditDrafts[gesture.id] = newValue
            }
        )
    }

    private func storedGestureName(for gesture: GestureDefinition) -> String? {
        storedGestureName(forGestureID: gesture.id) ?? gesture.name
    }

    private func storedGestureName(forGestureID gestureID: UUID) -> String? {
        viewModel.gestureConfiguration.gestures.first(where: { $0.id == gestureID })?.name
    }

    private func signatureCell(for gesture: GestureDefinition) -> some View {
        GestureSignaturePicker(
            selection: signatureBinding(for: gesture),
            gestureSignatures: gestureSignaturesBinding,
            onPersistCustomSignatures: {
                viewModel.commitGestureConfigurationToDisk()
            },
            onPauseGestureRecognition: viewModel.pauseGestureRecognition,
            onResumeGestureRecognition: viewModel.resumeGestureRecognition
        )
        .frame(width: 72, alignment: .leading)
        .simultaneousGesture(
            TapGesture().onEnded {
                commitFocusedNameEditing(for: gesture.id)
            }
        )
    }

    private var gestureSignaturesBinding: Binding<[GestureSignature]> {
        Binding(
            get: { viewModel.gestureConfiguration.gestureSignatures },
            set: { viewModel.gestureConfiguration.gestureSignatures = $0 }
        )
    }

    private func triggerCell(for gesture: GestureDefinition) -> some View {
        Picker("", selection: triggerBinding(for: gesture)) {
            Text(l10n.string(.gesturesTriggerRightMouse)).tag(GestureTrigger.rightMouse)
            Text(l10n.string(.gesturesTriggerMiddleMouse)).tag(GestureTrigger.middleMouse)
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    private func shortcutCell(for gesture: GestureDefinition) -> some View {
        ZStack {
            Button {
                commitFocusedNameEditing(for: gesture.id)
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

        let draft = nameEditDrafts[gestureID]
            ?? storedGestureName(for: gesture)
            ?? viewModel.localizedGestureName(gesture)
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let localizedDefault = viewModel.localizedGestureName(gesture)
        let resolvedName: String?
        if trimmed.isEmpty {
            resolvedName = nil
        } else if trimmed == localizedDefault, gesture.name == nil {
            resolvedName = nil
        } else {
            resolvedName = trimmed
        }

        if resolvedName != gesture.name {
            viewModel.stageGestureUpdate(id: gesture.id) { $0.name = resolvedName }
        }

        nameEditDrafts.removeValue(forKey: gestureID)
        viewModel.commitGesture(id: gestureID)
    }

    private func commitFocusedNameEditing(for gestureID: UUID) {
        guard focusedNameGestureID == gestureID else { return }
        commitNameDraft(for: gestureID)
        focusedNameGestureID = nil
    }

    private func activateGestureEditing(_ gestureID: UUID) {
        commitEditingGestureIfNeeded(leaving: gestureID)
        editingGestureID = gestureID
        selectedGestureIDs = [gestureID]
    }

    private func commitEditingGestureIfNeeded(leaving nextGestureID: UUID?) {
        guard let editingGestureID, editingGestureID != nextGestureID else { return }

        commitNameDraft(for: editingGestureID)
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
                commitFocusedNameEditing(for: gesture.id)
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
                commitFocusedNameEditing(for: gesture.id)
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
                commitFocusedNameEditing(for: gesture.id)
                activateGestureEditing(gesture.id)
                viewModel.stageGestureUpdate(id: gesture.id) { $0.isEnabled = newValue }
            }
        )
    }
}
