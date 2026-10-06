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
            gate.gestureActivation(at: GesturePoint(x: 10, y: 10))?.target,
            expectedTarget
        )
    }

    func testEmptyIgnoreListDefersTargetResolutionUntilFirstAccess() {
        let resolver = CountingGestureTargetResolver(
            resolvedTarget: ResolvedGestureTarget(bundleIdentifier: "com.example.app", processIdentifier: 42)
        )
        let gate = GestureActivationGate(
            configurationProvider: { AppConfiguration(ignoredApplicationBundleIdentifiers: []) },
            targetResolver: resolver
        )

        let activation = gate.gestureActivation(at: GesturePoint(x: 10, y: 10))
        XCTAssertEqual(resolver.resolvedPoints, [])

        XCTAssertEqual(activation?.target.processIdentifier, 42)
        XCTAssertEqual(activation?.target.processIdentifier, 42)
        XCTAssertEqual(resolver.resolvedPoints, [GesturePoint(x: 10, y: 10)])
    }

    func testIgnoredTargetReturnsNil() {
        let gate = makeGate(
            ignoredBundleIdentifiers: ["com.example.app"],
            resolvedTarget: ResolvedGestureTarget(
                bundleIdentifier: "com.example.app",
                processIdentifier: 42
            )
        )

        XCTAssertNil(gate.gestureActivation(at: GesturePoint(x: 10, y: 10)))
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
            gate.gestureActivation(at: GesturePoint(x: 10, y: 10))?.target,
            expectedTarget
        )
    }

    func testInvalidTargetStillActivates() {
        let gate = makeGate(
            ignoredBundleIdentifiers: ["com.example.app"],
            resolvedTarget: .invalid
        )

        XCTAssertEqual(
            gate.gestureActivation(at: GesturePoint(x: 10, y: 10))?.target,
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
            gate.gestureActivation(at: GesturePoint(x: 10, y: 10))?.target,
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

private final class CountingGestureTargetResolver: GestureTargetResolving, @unchecked Sendable {
    let resolvedTarget: ResolvedGestureTarget
    private(set) var resolvedPoints: [GesturePoint] = []

    init(resolvedTarget: ResolvedGestureTarget) {
        self.resolvedTarget = resolvedTarget
    }

    func resolve(
        policy: GestureTargetApplication,
        at startPoint: GesturePoint
    ) -> ResolvedGestureTarget {
        resolvedPoints.append(startPoint)
        return resolvedTarget
    }
}
