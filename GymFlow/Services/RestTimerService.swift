import Combine
import Foundation

@MainActor
final class RestTimerService: NSObject, ObservableObject {
    @Published private(set) var remainingSeconds = 0
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false

    private var endDate: Date?
    private var pausedRemaining = 0
    private var originalDuration = 0
    private var timer: Timer?
    private let defaults: UserDefaults
    private let keyPrefix: String
    var onCompletion: (() -> Void)?

    init(defaults: UserDefaults = .standard, keyPrefix: String = "restTimer") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        super.init()
        restore()
    }

    deinit { timer?.invalidate() }

    static func remaining(until endDate: Date, now: Date) -> Int {
        max(0, Int(ceil(endDate.timeIntervalSince(now))))
    }

    func start(duration: Int, now: Date = Date()) {
        guard duration > 0 else {
            cancel()
            return
        }
        originalDuration = duration
        pausedRemaining = 0
        endDate = now.addingTimeInterval(TimeInterval(duration))
        remainingSeconds = duration
        isRunning = true
        isPaused = false
        persist()
        scheduleTimer()
    }

    func pause(now: Date = Date()) {
        guard isRunning, let endDate else { return }
        pausedRemaining = Self.remaining(until: endDate, now: now)
        remainingSeconds = pausedRemaining
        self.endDate = nil
        isRunning = false
        isPaused = pausedRemaining > 0
        timer?.invalidate()
        persist()
    }

    func resume(now: Date = Date()) {
        guard isPaused, pausedRemaining > 0 else { return }
        endDate = now.addingTimeInterval(TimeInterval(pausedRemaining))
        remainingSeconds = pausedRemaining
        isRunning = true
        isPaused = false
        persist()
        scheduleTimer()
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        pausedRemaining = 0
        remainingSeconds = 0
        isRunning = false
        isPaused = false
        clearPersistence()
    }

    func restart(now: Date = Date()) {
        guard originalDuration > 0 else { return }
        start(duration: originalDuration, now: now)
    }

    func addThirtySeconds(now: Date = Date()) {
        if isRunning, let endDate {
            self.endDate = endDate.addingTimeInterval(30)
            remainingSeconds = Self.remaining(until: self.endDate ?? endDate, now: now)
        } else if isPaused {
            pausedRemaining += 30
            remainingSeconds = pausedRemaining
        } else {
            originalDuration = max(30, originalDuration + 30)
            start(duration: originalDuration, now: now)
            return
        }
        persist()
    }

    func skip() { cancel() }

    func refresh(now: Date = Date()) {
        guard isRunning, let endDate else { return }
        let remaining = Self.remaining(until: endDate, now: now)
        remainingSeconds = remaining
        if remaining == 0 { complete() }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let timer = Timer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(timerDidFire),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func timerDidFire() { refresh() }

    private func complete() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        pausedRemaining = 0
        remainingSeconds = 0
        isRunning = false
        isPaused = false
        clearPersistence()
        onCompletion?()
    }

    private func persist() {
        defaults.set(endDate, forKey: "\(keyPrefix).endDate")
        defaults.set(pausedRemaining, forKey: "\(keyPrefix).pausedRemaining")
        defaults.set(originalDuration, forKey: "\(keyPrefix).originalDuration")
        defaults.set(isPaused, forKey: "\(keyPrefix).isPaused")
    }

    private func restore(now: Date = Date()) {
        originalDuration = defaults.integer(forKey: "\(keyPrefix).originalDuration")
        let storedPaused = defaults.bool(forKey: "\(keyPrefix).isPaused")
        if storedPaused {
            pausedRemaining = defaults.integer(forKey: "\(keyPrefix).pausedRemaining")
            remainingSeconds = pausedRemaining
            isPaused = pausedRemaining > 0
        } else if let date = defaults.object(forKey: "\(keyPrefix).endDate") as? Date {
            let remaining = Self.remaining(until: date, now: now)
            if remaining > 0 {
                endDate = date
                remainingSeconds = remaining
                isRunning = true
                scheduleTimer()
            } else {
                clearPersistence()
            }
        }
    }

    private func clearPersistence() {
        ["endDate", "pausedRemaining", "originalDuration", "isPaused"].forEach {
            defaults.removeObject(forKey: "\(keyPrefix).\($0)")
        }
    }
}
