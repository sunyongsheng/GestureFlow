import Foundation

final class UpdateScheduler: @unchecked Sendable {
    static let defaultInterval: TimeInterval = 7 * 24 * 60 * 60

    private let interval: TimeInterval
    private let now: () -> Date
    private var timer: Timer?

    init(interval: TimeInterval = UpdateScheduler.defaultInterval, now: @escaping () -> Date = Date.init) {
        self.interval = interval
        self.now = now
    }

    func shouldPerformCheck(lastCheckDate: Date?) -> Bool {
        guard let lastCheckDate else { return true }
        return now().timeIntervalSince(lastCheckDate) >= interval
    }

    func startRepeating(onFire: @escaping () -> Void) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            onFire()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
