import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureActivationGateTests: XCTestCase {
    func testEmptyIgnoreListReturnsResolvedTarget() {
        let expectedTarget = ResolvedGestureTarget(
            bundleIdentifier: "com.example.app",
            processIdentifier: 42
        )
        let gate = makeGate(
            ignoredBundleIdentifiers: [],
            resolvedTarget: expectedTarget
        )

        XCTAssertEqual(
            gate.resolvedTargetForGestureActivation(at: GesturePoint(x: 10, y: 10)),
            expectedTarget
        )
    }

    func testIgnoredTargetReturnsNil() {
        let gate = makeGate(
            ignoredBundleIdentifiers: ["com.example.app"],
            resolvedTarget: ResolvedGestureTarget(
                bundleIdentifier: "com.example.app",
                processIdentifier: 42
            )
        )

        XCTAssertNil(gate.resolvedTargetForGestureActivation(at: GesturePoint(x: 10, y: 10)))
    }

    func testNonIgnoredTargetReturnsResolvedTarget() {
        let expectedTarget = ResolvedGestureTarget(
            bundleIdentifier: "com.example.app",
            processIdentifier: 42
        )
        let gate = makeGate(
            ignoredBundleIdentifiers: ["com.example.other"],
            resolvedTarget: expectedTarget
        )

        XCTAssertEqual(
            gate.resolvedTargetForGestureActivation(at: GesturePoint(x: 10, y: 10)),
            expectedTarget
        )
    }

    func testInvalidTargetStillActivates() {
        let gate = makeGate(
            ignoredBundleIdentifiers: ["com.example.app"],
            resolvedTarget: .invalid
        )

        XCTAssertEqual(
            gate.resolvedTargetForGestureActivation(at: GesturePoint(x: 10, y: 10)),
            .invalid
        )
    }

    func testOwnBundleAlwaysActivatesEvenWhenListed() {
        let expectedTarget = ResolvedGestureTarget(
            bundleIdentifier: "com.gestureflow.app",
            processIdentifier: 42
        )
        let gate = makeGate(
            ignoredBundleIdentifiers: ["com.gestureflow.app"],
            resolvedTarget: expectedTarget,
            ownBundleIdentifier: "com.gestureflow.app"
        )

        XCTAssertEqual(
            gate.resolvedTargetForGestureActivation(at: GesturePoint(x: 10, y: 10)),
            expectedTarget
        )
    }

    private func makeGate(
        ignoredBundleIdentifiers: [String],
        resolvedTarget: ResolvedGestureTarget,
        ownBundleIdentifier: String? = "com.test.host"
    ) -> GestureActivationGate {
        let configuration = AppConfiguration(
            ignoredApplicationBundleIdentifiers: ignoredBundleIdentifiers
        )
        return GestureActivationGate(
            configurationProvider: { configuration },
            targetResolver: StubGestureTargetResolver(resolvedTarget: resolvedTarget),
            ownBundleIdentifier: ownBundleIdentifier
        )
    }
}

private struct StubGestureTargetResolver: GestureTargetResolving {
    let resolvedTarget: ResolvedGestureTarget

    func resolve(
        policy: GestureTargetApplication,
        at startPoint: GesturePoint
    ) -> ResolvedGestureTarget {
        resolvedTarget
    }
}
