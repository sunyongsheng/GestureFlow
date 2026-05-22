# Settings Minimal Header Cleanup Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the settings pages by removing page-level headers and trimming redundant copy from the General page.

**Architecture:** Keep the existing settings navigation and card structure. Remove only page-top headings/subheadings from `SettingsPage` and trim General page labels so the UI becomes more minimal without changing behavior.

**Tech Stack:** Swift, SwiftUI, XCTest.

---

## Chunk 1: Trim Settings Copy

### Task 1: Remove page-level headers

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/SettingsSidebarModels.swift`

- [ ] **Step 1: Update `SettingsPage` so it renders content directly without the page title/description block**
- [ ] **Step 2: Build to confirm no call-site changes are needed**

### Task 2: Simplify General page copy

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/GeneralSettingsView.swift`

- [ ] **Step 1: Remove the card title and subtitle from the General page card**
- [ ] **Step 2: Remove the running/stopped status text from the gesture recognition row**
- [ ] **Step 3: Remove the title and explanatory copy above the quit button, leaving only the button**
- [ ] **Step 4: Build and verify no behavior changed**

## Chunk 2: Verification

### Task 3: Run focused checks

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/SettingsSidebarModels.swift`
- Modify: `Sources/GestureFlowApp/Settings/GeneralSettingsView.swift`

- [ ] **Step 1: Run app-shell tests**
- [ ] **Step 2: Check diagnostics for edited files**
- [ ] **Step 3: Skip commit because current flow is not creating git commits**
