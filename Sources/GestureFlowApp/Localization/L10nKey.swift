import Foundation

enum L10nKey: String, CaseIterable {
    case settingsSectionGeneral
    case settingsSectionAdvanced
    case settingsSectionGestures
    case settingsSectionAbout
    case settingsLoading
    case settingsCommandSettings
    case settingsRecoveryTitle
    case settingsSaveFailed
    case settingsRestoreDefaultsTitle
    case settingsConfirm
    case settingsCancel
    case settingsRestoreDefaults

    case statusBarStart
    case statusBarStop
    case statusBarSettings
    case statusBarQuit
    case statusBarToolTip
    case statusBarTitleRunning

    case generalLaunchAtLoginTitle
    case generalLaunchAtLoginDescription
    case generalGestureRecognitionTitle
    case generalGestureRecognitionDescription
    case generalAppLanguageTitle
    case generalAppLanguageDescription
    case generalConfigDirectoryTitle
    case generalConfigDirectoryDescription
    case generalConfigDirectoryPathPlaceholder
    case generalConfigDirectoryResetHelp
    case generalConfigDirectoryXDGHelp
    case generalConfigDirectoryConfirmHelp
    case generalAccessibilityTitle
    case generalAccessibilityTrustedDescription
    case generalAccessibilityUntrustedDescription
    case generalAccessibilityTrustedButton
    case generalAccessibilityRequestButton
    case generalQuitApplication
    case generalConfigAdoptionAlertTitle
    case generalConfigAdoptionAlertNo
    case generalConfigAdoptionAlertYes
    case generalConfigAdoptionAlertMessage

    case permissionGuideTitle
    case permissionGuideTrustedDescription
    case permissionGuideUntrustedDescription
    case permissionGuideRequestButton

    case feedbackCardTitle
    case feedbackCardDescription
    case feedbackLiquidGlassTitle
    case feedbackLiquidGlassDescription
    case feedbackTrailTitle
    case feedbackTrailDescription
    case feedbackTrailColorTitle
    case feedbackTrailColorDescription
    case feedbackTrailWidthTitle
    case feedbackTrailWidthDescription
    case feedbackTrailOpacityTitle
    case feedbackTrailOpacityDescription
    case feedbackTrailStrokeEnabledTitle
    case feedbackTrailStrokeEnabledDescription
    case feedbackTrailStrokeColorTitle
    case feedbackTrailStrokeColorDescription
    case feedbackTrailStrokeWidthTitle
    case feedbackTrailStrokeWidthDescription
    case feedbackTrailColorPickerHelp
    case feedbackTrailStrokeColorPickerHelp
    case feedbackTrailPreviewLabel
    case feedbackTrailPreviewAccessibility

    case advancedTriggerTitle
    case advancedTriggerDescription
    case advancedGestureTargetTitle
    case advancedGestureTargetDescription
    case advancedMovementThresholdTitle
    case advancedMovementThresholdDescription
    case advancedHoldTimeoutTitle
    case advancedHoldTimeoutDescription
    case advancedSampleDistanceTitle
    case advancedSampleDistanceDescription

    case advancedIgnoredAppsTitle
    case advancedIgnoredAppsDescription
    case advancedIgnoredAppsEmpty
    case advancedIgnoredAppsAdd
    case advancedIgnoredAppsAddFromFile
    case advancedIgnoredAppsAddFromRunning
    case advancedIgnoredAppsRunningEmpty
    case advancedIgnoredAppsRemoveHelp

    case gesturesApplicationsLabel
    case gesturesGlobalScope
    case gesturesAddApplication
    case gesturesDeleteApplicationHelp
    case gesturesRestoreDefaults
    case gesturesAddGestureHelp
    case gesturesDeleteGestureHelp
    case gesturesRestoreDefaultsAlertTitle
    case gesturesRestoreDefaultsConfirm
    case gesturesRestoreDefaultsMessage
    case gesturesColumnName
    case gesturesColumnSignature
    case gesturesColumnTrigger
    case gesturesColumnShortcut
    case gesturesColumnEnabled
    case gesturesNamePlaceholder
    case gesturesTriggerRightMouse
    case gesturesTriggerMiddleMouse
    case gesturesDrawCustomSignatureHelp
    case gesturesDrawCustomSignatureAccessibility
    case gesturesRecordingSheetTitle
    case gesturesRecordingSheetCancel
    case gesturesRecordingSheetConfirm
    case gesturesRecordingCanvasHint
    case gesturesNewGestureName

    case aboutCardDescription
    case aboutVersionLabel
    case aboutBuildLabel
    case aboutDevelopmentEnvironment
    case aboutBuildUnavailable

    case overlayUnmatchedGesture

    case engineUnderMouseTargetMissing
    case engineTargetDeliveryFailed

    case shortcutClickToRecord
    case shortcutRecording

    case gestureTargetForeground
    case gestureTargetUnderMouse
    case builtInCloseWindowGestureName
    case builtInBackGestureName
    case builtInForwardGestureName
    case builtInNewTabGestureName
    case builtInRefreshGestureName
    case builtInMinimizeGestureName
    case builtInUndoGestureName
    case builtInRedoGestureName
    case builtInCopyGestureName
    case builtInPasteGestureName
    case builtInFindGestureName
    case builtInQuitAppGestureName
    case builtInChromeScrollToTopGestureName
    case builtInChromeScrollToBottomGestureName
    case builtInChromeReopenClosedTabGestureName
    case builtInChromeFocusAddressBarGestureName
    case builtInFinderParentFolderGestureName
    case builtInFinderOpenItemGestureName
    case builtInFinderNewFolderGestureName

    case gestureDirectionUp
    case gestureDirectionDown
    case gestureDirectionLeft
    case gestureDirectionRight

    case recoveryWithBackup
    case recoveryWithoutBackup

    case errorGestureDuplicate
    case errorGestureMergeConflict
    case errorRecordShortcut
    case errorBundleIdentifierUnreadable
    case errorConfigDirectoryInvalidPath
    case errorConfigDirectoryNotADirectory
    case errorConfigDirectoryNotWritable
    case errorConfigDirectoryUnchanged
    case errorConfigDirectoryCopyFailed
    case errorConfigDirectoryWriteFailed
    case errorConfigDirectoryInvalidContent

    case sliderValueFieldHelp
}
