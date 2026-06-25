import Foundation

final class UpdateScheduler: @unchecked Sendable {
    private var interval: TimeInterval
    private let now: () -> Date
    private var timer: Timer?

    init(intervalHours: Int = 168, now: @escaping () -> Date = Date.init) {
        self.interval = TimeInterval(intervalHours) * 3600
        self.now = now
    }

    func updateInterval(hours: Int) {
        interval = TimeInterval(hours) * 3600
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
