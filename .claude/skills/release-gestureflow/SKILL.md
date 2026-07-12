---
name: release-gestureflow
description: Release a new version of GestureFlow. Bumps version numbers, drafts CHANGELOG for user confirmation, then updates CHANGELOG, commits, tags, and pushes. Use when user says "发布版本", "更新版本", "更新一个小版本", "bump version", "release X.Y.Z", "发布 X.Y.Z".
---

# GestureFlow Release

Automates the full release process for GestureFlow.

## Trigger

Activate when the user mentions any of:

- 发布版本 / 发布一个小版本 / 发布 X.Y.Z / release X.Y.Z
- 更新版本 / 更新一个小版本 / 更新一个大版本
- bump version / new release / 发新版

## Workflow

### Step 1: Determine Version

Read the current version from `Resources/Info.plist` (`CFBundleShortVersionString`).

If the user provides a target version, require it to match `X.Y.Z` or `vX.Y.Z`; normalize it to `X.Y.Z` and reject any other format, asking for a valid version if needed.
Otherwise, infer from context:

- "小版本" / "patch" → bump patch (0.2.4 → 0.2.5)
- "中版本" / "minor" → bump minor (0.2.4 → 0.3.0)
- "大版本" / "major" → bump major (0.2.4 → 1.0.0)

Default to **patch** if unspecified.

Also increment `CFBundleVersion` (build number) by 1.

### Step 2: Update Version in 3 Files

| File                                    | Field                               | Example            |
| --------------------------------------- | ----------------------------------- | ------------------ |
| `Resources/Info.plist`                  | `CFBundleShortVersionString`        | `0.2.5`            |
| `Resources/Info.plist`                  | `CFBundleVersion`                   | `7` (previous + 1) |
| `GestureFlow.xcodeproj/project.pbxproj` | `MARKETING_VERSION` (2 occurrences) | `0.2.5`            |

### Step 3: Generate and Confirm CHANGELOG

**Do not modify `CHANGELOG.md` until the user has explicitly confirmed the draft.**

#### 3a. Generate draft

Determine the changelog content from git history:

1. Find the previous release tag: `git describe --tags --abbrev=0 --match 'release/v*'`. If no prior release tag exists (command fails), this is the first release; create a changelog section without a commit range and note that this is the initial version.
2. List commits since the previous tag: `git log <prev_tag>..HEAD --oneline`. For the first release, use: `git log --oneline`
3. Summarize into user-facing bullet points (exclude CI fixes, docs-only changes)

Draft the new section using today's date:

```markdown
## [X.Y.Z] - YYYY-MM-DD

- <summarize changes from git log since last tag>
```

**Changelog writing rules:**

- Do NOT include specific app names, third-party product names, or concrete examples (e.g. "e.g. Feishu", "such as Chrome") in changelog entries. Describe the fix/feature in generic, user-facing terms only.
- Good: "Fix gestures on inactive app windows being incorrectly dispatched to the app underneath"
- Bad: "Fix gestures on inactive app windows (e.g. Finder) being dispatched to the app underneath"

#### 3b. Present draft and wait for confirmation

Show the **full draft section** to the user in your response (the `## [X.Y.Z] - YYYY-MM-DD` block with all bullet points).

Ask explicitly whether the draft meets their requirements, or whether they want edits.

**STOP HERE and wait for the user's reply.** Do not:

- write to `CHANGELOG.md`
- commit, push, or tag

If the user requests changes, revise the draft and present it again. Repeat until they explicitly confirm (e.g. "确认", "可以", "OK", "proceed").

#### 3c. Apply CHANGELOG (after confirmation only)

Once the user has confirmed, insert the **confirmed** section at the top of `CHANGELOG.md` (below the file header).

Then continue with Steps 4–7.

### Step 4: Commit

```bash
git add Resources/Info.plist GestureFlow.xcodeproj/project.pbxproj CHANGELOG.md
git commit -m "chore: bump version to X.Y.Z"
```



### Step 5: Push

```bash
git push
```



### Step 6: Create and Push Tag

Tag format is `release/vX.Y.Z`:

```bash
git tag release/vX.Y.Z
git push origin release/vX.Y.Z
```



### Step 7: Report

Tell the user:

- The version that was released
- That CI will automatically build, sign, and create the GitHub Release
- Link: `https://github.com/sunyongsheng/GestureFlow/actions`



## CI (Automated, No Action Needed)

After the tag push, `.github/workflows/release.yml` automatically:

1. Runs tests
2. Signs and packages `.zip` + `.dmg`
3. Generates Sparkle `appcast.xml`
4. Creates GitHub Release with artifacts



## Fixing a Failed Release

If CI fails after tagging:

1. Fix the issue and push to main
2. Move the tag:

```bash
git tag -d release/vX.Y.Z
git tag release/vX.Y.Z
git push origin :refs/tags/release/vX.Y.Z
git push origin release/vX.Y.Z
```



## Required Secrets (pre-configured in repo)

- `MACOS_CERTIFICATE` — signing cert (base64 .p12)
- `MACOS_CERTIFICATE_PWD` — cert password
- `MACOS_SIGNING_IDENTITY` — code sign identity
- `KEYCHAIN_PASSWORD` — temp keychain password
- `SPARKLE_PRIVATE_KEY` — Sparkle EdDSA key (base64)

