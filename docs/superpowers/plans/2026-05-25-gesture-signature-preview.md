# Gesture Signature Preview Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show schematic gesture path previews (with terminal arrow) in the settings signature picker instead of visible Chinese labels, in both collapsed and menu states.

**Architecture:** `GestureSignaturePathGeometry` in Core computes polylines and normalized fit; `GestureSignaturePreview` in App renders at 40×40 pt; `GestureSettingsView` wires Picker label + items; catalog `id` becomes token-based key while `displayName` stays for a11y/help.

**Tech Stack:** Swift 5.9, SwiftUI, GestureFlowCore + GestureFlowApp (macOS 14+)

**Spec:** [2026-05-25-gesture-signature-preview-design.md](../specs/2026-05-25-gesture-signature-preview-design.md)

---

## File Map

| File | Responsibility |
| --- | --- |
| `Sources/GestureFlowCore/Recognition/GestureSignaturePathGeometry.swift` | Polyline + fit + terminal direction |
| `Tests/GestureFlowCoreTests/GestureSignaturePathGeometryTests.swift` | Geometry unit tests |
| `Sources/GestureFlowCore/Recognition/GestureSignatureCatalog.swift` | Stable `id` from token raw values |
| `Tests/GestureFlowCoreTests/GestureSignatureCatalogTests.swift` | Update id assertion |
| `Sources/GestureFlowApp/Settings/Gestures/UI/GestureSignaturePreview.swift` | SwiftUI glyph view |
| `Sources/GestureFlowApp/Settings/Gestures/UI/GestureSettingsView.swift` | Picker + column width |

---

## Chunk 1: Core geometry

### Task 1: `GestureSignaturePathGeometry`

**Files:**
- Create: `Sources/GestureFlowCore/Recognition/GestureSignaturePathGeometry.swift`
- Test: `Tests/GestureFlowCoreTests/GestureSignaturePathGeometryTests.swift`

- [ ] **Step 1: Write failing geometry tests**

Create `Tests/GestureFlowCoreTests/GestureSignaturePathGeometryTests.swift`:

```swift
import XCTest
@testable import GestureFlowCore

final class GestureSignaturePathGeometryTests: XCTestCase {
    func testDownRightPolylineHasThreeVertices() {
        let signature = GestureSignature(tokens: [.down, .right])
        let polyline = GestureSignaturePathGeometry.polyline(for: signature)
        XCTAssertEqual(polyline.count, 3)
        XCTAssertEqual(polyline[0], PathPoint(x: 0, y: 0))
        XCTAssertEqual(polyline[1], PathPoint(x: 0, y: 1))
        XCTAssertEqual(polyline[2], PathPoint(x: 1, y: 1))
    }

    func testTerminalDirectionForDownRight() {
        let signature = GestureSignature(tokens: [.down, .right])
        XCTAssertEqual(GestureSignaturePathGeometry.terminalDirection(for: signature), .right)
    }

    func testSingleSegmentLeft() {
        let signature = GestureSignature(tokens: [.left])
        let polyline = GestureSignaturePathGeometry.polyline(for: signature)
        XCTAssertEqual(polyline.count, 2)
        XCTAssertEqual(GestureSignaturePathGeometry.terminalDirection(for: signature), .left)
    }

    func testFittedPolylineStaysInsideUnitSquare() {
        let signature = GestureSignature(tokens: [.down, .right])
        let fitted = GestureSignaturePathGeometry.fittedPolyline(for: signature)
        XCTAssertEqual(fitted.count, 3)
        for point in fitted {
            XCTAssertGreaterThanOrEqual(point.x, 0)
            XCTAssertLessThanOrEqual(point.x, 1)
            XCTAssertGreaterThanOrEqual(point.y, 0)
            XCTAssertLessThanOrEqual(point.y, 1)
        }
    }

    func testEmptyTokensReturnsEmptyPolyline() {
        let signature = GestureSignature(tokens: [])
        XCTAssertTrue(GestureSignaturePathGeometry.polyline(for: signature).isEmpty)
        XCTAssertNil(GestureSignaturePathGeometry.terminalDirection(for: signature))
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `swift test --filter GestureSignaturePathGeometryTests`
Expected: FAIL — `GestureSignaturePathGeometry` / `PathPoint` not found

- [ ] **Step 3: Implement geometry**

Create `Sources/GestureFlowCore/Recognition/GestureSignaturePathGeometry.swift`:

```swift
import Foundation

public struct PathPoint: Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum GestureSignaturePathGeometry {
    private static let unitSegmentLength: Double = 1

    public static func polyline(for signature: GestureSignature) -> [PathPoint] {
        guard !signature.tokens.isEmpty else { return [] }

        var points = [PathPoint(x: 0, y: 0)]
        var x = 0.0
        var y = 0.0

        for direction in signature.tokens {
            switch direction {
            case .up:
                y -= unitSegmentLength
            case .down:
                y += unitSegmentLength
            case .left:
                x -= unitSegmentLength
            case .right:
                x += unitSegmentLength
            }
            points.append(PathPoint(x: x, y: y))
        }

        return points
    }

    public static func terminalDirection(for signature: GestureSignature) -> GestureDirection? {
        signature.tokens.last
    }

    public static func fittedPolyline(
        for signature: GestureSignature,
        paddingRatio: Double = 0.12
    ) -> [PathPoint] {
        let points = polyline(for: signature)
        guard !points.isEmpty else { return [] }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return points
        }

        let width = max(maxX - minX, 1e-6)
        let height = max(maxY - minY, 1e-6)
        let padding = max(0, min(paddingRatio, 0.4))
        let inner = 1 - 2 * padding
        let scale = min(inner / width, inner / height)

        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        return points.map { point in
            let nx = 0.5 + (point.x - centerX) * scale
            let ny = 0.5 + (point.y - centerY) * scale
            return PathPoint(x: nx, y: ny)
        }
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `swift test --filter GestureSignaturePathGeometryTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowCore/Recognition/GestureSignaturePathGeometry.swift \
  Tests/GestureFlowCoreTests/GestureSignaturePathGeometryTests.swift
git commit -m "feat(core): add gesture signature path geometry"
```

---

### Task 2: Catalog stable `id`

**Files:**
- Modify: `Sources/GestureFlowCore/Recognition/GestureSignatureCatalog.swift`
- Modify: `Tests/GestureFlowCoreTests/GestureSignatureCatalogTests.swift`

- [ ] **Step 1: Update catalog test for stable id**

In `GestureSignatureCatalogTests.swift`, add or extend:

```swift
func testStableIDForDownRight() {
    let signature = GestureSignature(tokens: [.down, .right])
    let option = GestureSignatureCatalog.all.first { $0.signature == signature }
    XCTAssertEqual(option?.id, "D,R")
    XCTAssertEqual(option?.displayName, "下、右")
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `swift test --filter GestureSignatureCatalogTests.testStableIDForDownRight`
Expected: FAIL — id still equals displayName

- [ ] **Step 3: Change `GestureSignatureOption.id`**

In `GestureSignatureCatalog.swift`, replace stored `id` with computed:

```swift
public var id: String {
    signature.tokens.map(\.rawValue).joined(separator: ",")
}
```

Remove `id` from `init` if it was only `displayName`; keep `displayName` property for a11y.

- [ ] **Step 4: Run catalog tests — expect PASS**

Run: `swift test --filter GestureSignatureCatalogTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowCore/Recognition/GestureSignatureCatalog.swift \
  Tests/GestureFlowCoreTests/GestureSignatureCatalogTests.swift
git commit -m "refactor(core): use token-based ids in gesture signature catalog"
```

---

## Chunk 2: App preview + settings UI

### Task 3: `GestureSignaturePreview` view

**Files:**
- Create: `Sources/GestureFlowApp/Settings/Gestures/UI/GestureSignaturePreview.swift`

- [ ] **Step 1: Add preview view and shape**

Create `GestureSignaturePreview.swift`:

```swift
import SwiftUI
import GestureFlowCore

struct GestureSignaturePreview: View {
    let signature: GestureSignature

    var body: some View {
        GestureSignatureGlyphShape(signature: signature)
            .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
    }
}

private struct GestureSignatureGlyphShape: Shape {
    let signature: GestureSignature

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let fitted = GestureSignaturePathGeometry.fittedPolyline(for: signature)
        guard fitted.count >= 2 else { return path }

        let points = fitted.map { point in
            CGPoint(
                x: rect.minX + CGFloat(point.x) * rect.width,
                y: rect.minY + CGFloat(point.y) * rect.height
            )
        }

        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        if let direction = GestureSignaturePathGeometry.terminalDirection(for: signature),
           let tip = points.last,
           let previous = points.dropLast().last {
            appendArrow(to: &path, tip: tip, direction: direction, segment: CGPoint(
                x: tip.x - previous.x,
                y: tip.y - previous.y
            ), size: min(rect.width, rect.height) * 0.18)
        }

        return path
    }

    private func appendArrow(
        to path: inout Path,
        tip: CGPoint,
        direction: GestureDirection,
        segment: CGPoint,
        size: CGFloat
    ) {
        let length = max(hypot(segment.x, segment.y), 0.001)
        let ux = segment.x / length
        let uy = segment.y / length
        let px = -uy
        let py = ux
        let back = CGPoint(x: tip.x - ux * size, y: tip.y - uy * size)
        let left = CGPoint(x: back.x + px * size * 0.45, y: back.y + py * size * 0.45)
        let right = CGPoint(x: back.x - px * size * 0.45, y: back.y - py * size * 0.45)
        path.move(to: left)
        path.addLine(to: tip)
        path.addLine(to: right)
        path.closeSubpath()
    }
}
```

Note: `Shape` stroke draws open path; arrow fill may need a second `fill` pass. If arrow does not fill with single `.stroke`, split into:

```swift
GestureSignatureGlyphShape(...)
    .stroke(...)
// and overlay filled arrow subpath — adjust during implementation if visual QA shows hollow arrow.

Preferred fix if needed: use `Canvas` or return combined path where shaft is stroked via separate `Path` in View body with `ZStack`.

- [ ] **Step 2: Build app target**

Run: `swift build --target GestureFlowApp`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/GestureFlowApp/Settings/Gestures/UI/GestureSignaturePreview.swift
git commit -m "feat(app): add gesture signature preview glyph view"
```

---

### Task 4: Wire `GestureSettingsView`

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/Gestures/UI/GestureSettingsView.swift`

- [ ] **Step 1: Update column widths**

In `gestureListHeader` and `gestureListRow`:

- Change `手势` column from `width: 100` to `width: 92` (header and `signatureCell` frame).

- [ ] **Step 2: Replace `signatureCell` picker content**

Replace `signatureCell(for:)` implementation:

```swift
private func signatureCell(for gesture: GestureDefinition) -> some View {
    let binding = signatureBinding(for: gesture)
    let currentSignature = binding.wrappedValue

    return Picker("", selection: binding) {
        ForEach(GestureSignatureCatalog.all) { option in
            GestureSignaturePreview(signature: option.signature)
                .accessibilityLabel(option.displayName)
                .help(option.displayName)
                .tag(option.signature)
        }
    } label: {
        GestureSignaturePreview(signature: currentSignature)
            .accessibilityLabel(currentSignature.chineseDisplayName)
            .help(currentSignature.chineseDisplayName)
    }
    .labelsHidden()
    .frame(width: 92, alignment: .leading)
}
```

- [ ] **Step 3: Run full test suite**

Run: `swift test`
Expected: All tests PASS

- [ ] **Step 4: Manual check (macOS)**

1. Build and run `GestureFlowApp`.
2. Open Settings → 手势.
3. Confirm collapsed signature cell shows L-shaped preview for default `下、右` gesture.
4. Open picker — 52 items show glyphs, no Chinese in menu rows.
5. VoiceOver / hover: help text still shows Chinese names.

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Settings/Gestures/UI/GestureSettingsView.swift
git commit -m "feat(app): show signature previews in gesture settings picker"
```

---

## Chunk 3: Docs touch-up (optional)

### Task 5: Spec cross-reference

**Files:**
- Modify: `docs/superpowers/specs/2026-05-23-gesture-scoped-settings-design.md` (one-line note under signature column)

- [ ] Add footnote: signature column UI superseded by `2026-05-25-gesture-signature-preview-design.md`.

- [ ] Commit if edited:

```bash
git add docs/superpowers/specs/2026-05-23-gesture-scoped-settings-design.md
git commit -m "docs: note signature preview supersedes Chinese picker labels"
```

---

## Verification Checklist

- [ ] `swift test` green
- [ ] `swift build` green
- [ ] Picker collapsed + menu show 40×40 previews
- [ ] `accessibilityLabel` / `.help` retain Chinese
- [ ] No visible `Text(option.displayName)` in signature column
