import AppKit
import Combine
import GestureFlowCore

final class GestureOverlayView: NSView {
    private var points: [GesturePoint] = []
    private var trailAppearance = GestureTrailAppearance(feedback: .default)
    private var marker: GestureOverlayMarker?
    private let trailView = GestureTrailView()
    private let feedbackCardView = GestureFeedbackCardView()
    private var trailDisplayLink: CADisplayLink?
    private let localization: LocalizationManager
    private var visibleLiveFeedback: LiveGestureOverlayFeedback?
    private var visibleLiveFeedbackFrame: CGRect?
    private var visibleCompletion: GestureOverlayCompletion?
    private var visibleCompletionFrame: CGRect?
    private var languageObserver: AnyCancellable?

    override var isFlipped: Bool { true }

    override var isOpaque: Bool { false }

    init(frame frameRect: NSRect, localization: LocalizationManager) {
        self.localization = localization
        super.init(frame: frameRect)
        configureSubviews()
        languageObserver = localization.objectWillChange.sink { [weak self] _ in
            self?.refreshVisibleFeedback()
        }
    }

    override init(frame frameRect: NSRect) {
        self.localization = AppServices.localization
        super.init(frame: frameRect)
        configureSubviews()
        languageObserver = localization.objectWillChange.sink { [weak self] _ in
            self?.refreshVisibleFeedback()
        }
    }

    required init?(coder: NSCoder) {
        self.localization = AppServices.localization
        super.init(coder: coder)
        configureSubviews()
        languageObserver = localization.objectWillChange.sink { [weak self] _ in
            self?.refreshVisibleFeedback()
        }
    }

    deinit {
        trailDisplayLink?.invalidate()
    }

    func begin(at point: GesturePoint, appearance: GestureTrailAppearance) {
        self.points = [point]
        self.trailAppearance = appearance
        self.marker = nil
        visibleLiveFeedback = nil
        visibleLiveFeedbackFrame = nil
        visibleCompletion = nil
        visibleCompletionFrame = nil
        feedbackCardView.hide()
        renderTrail()
    }

    func append(_ point: GesturePoint) {
        points.append(point)
        scheduleTrailRender()
    }

    func updateLive(appearance: GestureTrailAppearance, feedback: LiveGestureOverlayFeedback, feedbackFrame: CGRect?) {
        let trailAppearanceChanged = appearance != trailAppearance
        trailAppearance = appearance
        visibleCompletion = nil
        visibleCompletionFrame = nil
        visibleLiveFeedback = feedback.showsCard ? feedback : nil
        visibleLiveFeedbackFrame = feedbackFrame
        if feedback.showsCard, let message = liveFeedbackMessage(for: feedback), let feedbackFrame {
            feedbackCardView.show(
                message: message,
                in: feedbackFrame,
                textColor: .labelColor,
                cornerRadius: CGFloat(trailAppearance.feedbackCardCornerRadius),
                liquidGlassEnabled: trailAppearance.feedbackCardLiquidGlassEnabled
            )
        } else {
            feedbackCardView.hide()
        }
        if trailAppearanceChanged {
            renderTrail()
        }
    }

    func complete(with completion: GestureOverlayCompletion, feedbackFrame: CGRect?) {
        visibleLiveFeedback = nil
        visibleLiveFeedbackFrame = nil
        visibleCompletion = completion
        visibleCompletionFrame = feedbackFrame
        if let feedbackFrame, let message = overlayMessage(for: completion) {
            feedbackCardView.show(
                message: message,
                in: feedbackFrame,
                textColor: .labelColor,
                cornerRadius: CGFloat(trailAppearance.feedbackCardCornerRadius),
                liquidGlassEnabled: trailAppearance.feedbackCardLiquidGlassEnabled
            )
        } else {
            feedbackCardView.hide()
        }
    }

    func showMarker(_ marker: GestureOverlayMarker, appearance: GestureTrailAppearance) {
        self.marker = marker
        self.trailAppearance = appearance
        self.points = []
        feedbackCardView.hide()
        renderTrail()
    }

    func clearMarker() {
        marker = nil
        renderTrail()
    }

    func reset() {
        points = []
        marker = nil
        visibleLiveFeedback = nil
        visibleLiveFeedbackFrame = nil
        visibleCompletion = nil
        visibleCompletionFrame = nil
        feedbackCardView.hide()
        renderTrail()
    }

    /// Pushes the trail state to the layers now, superseding a render still waiting for the display refresh.
    func renderTrail() {
        trailDisplayLink?.isPaused = true
        trailView.render(points: points, appearance: trailAppearance, marker: marker)
    }

    /// Mouse samples can arrive several times per frame and every render resends the whole path to the render
    /// server, so appended points are rendered once per display refresh.
    private func scheduleTrailRender() {
        // Outside a window there is no display whose refresh could be waited for.
        guard window != nil else {
            renderTrail()
            return
        }
        if trailDisplayLink == nil {
            let link = displayLink(
                target: TrailDisplayLinkTarget(view: self),
                selector: #selector(TrailDisplayLinkTarget.displayDidRefresh)
            )
            link.add(to: .main, forMode: .common)
            trailDisplayLink = link
        }
        trailDisplayLink?.isPaused = false
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        renderTrail()
    }

    func refreshVisibleFeedback() {
        if let feedback = visibleLiveFeedback, let feedbackFrame = visibleLiveFeedbackFrame {
            updateLive(appearance: trailAppearance, feedback: feedback, feedbackFrame: feedbackFrame)
        } else if let completion = visibleCompletion {
            complete(with: completion, feedbackFrame: visibleCompletionFrame)
        }
    }

    private func liveFeedbackMessage(for feedback: LiveGestureOverlayFeedback) -> String? {
        if let gestureID = feedback.matchedGestureID {
            let displayName = localization.localizedGestureDisplayName(
                id: gestureID,
                storedName: feedback.matchedGestureStoredName
            )
            if !displayName.isEmpty {
                return displayName
            }
        }
        return feedback.message
    }

    private func overlayMessage(for completion: GestureOverlayCompletion) -> String? {
        switch completion {
        case let .recognized(gestureID, storedName),
             let .targetNotFound(gestureID, storedName),
             let .shortcutNotConfigured(gestureID, storedName),
             let .deliveryFailed(gestureID, storedName),
             let .executionFailed(gestureID, storedName):
            return localization.localizedGestureDisplayName(id: gestureID, storedName: storedName)
        case .unmatched:
            return localization.string(.overlayUnmatchedGesture)
        case .rejected:
            return nil
        }
    }

    var hasVisibleContent: Bool {
        !points.isEmpty || feedbackCardView.isVisible || marker != nil
    }

    private func configureSubviews() {
        trailView.frame = bounds
        trailView.autoresizingMask = [.width, .height]
        addSubview(trailView)
        feedbackCardView.isHidden = true
        addSubview(feedbackCardView, positioned: .above, relativeTo: trailView)
    }
}

/// `CADisplayLink` retains its target; the weak hop lets an overlay view go away while its link is still scheduled.
private final class TrailDisplayLinkTarget: NSObject {
    private weak var view: GestureOverlayView?

    init(view: GestureOverlayView) {
        self.view = view
    }

    @objc func displayDidRefresh(_ link: CADisplayLink) {
        view?.renderTrail()
    }
}
