import Combine
import Foundation

@MainActor
final class RestTimerService: NSObject, ObservableObject {
    struct ActivityState: Equatable {
        let deadline: Date?
        let pausedSeconds: Int
        let didComplete: Bool
    }

    @Published private(set) var remainingSeconds = 0
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var didComplete = false
    @Published private(set) var stateRevision = 0

    private var endDate: Date?
    private var pausedRemaining = 0
    private var originalDuration = 0
    private var timer: Timer?
    private let defaults: UserDefaults
    private let keyPrefix: String
    private let notificationScheduler: RestTimerNotificationScheduling?
    private let notificationIdentifier: String?
    private(set) var notificationSoundEnabled = true
    var onCompletion: (() -> Void)?
    var deadline: Date? { endDate }

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "restTimer",
        migrationKeyPrefix: String? = nil,
        sessionID: UUID? = nil,
        notificationScheduler: RestTimerNotificationScheduling? = nil
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        self.notificationScheduler = notificationScheduler
        self.notificationIdentifier = sessionID.map(RestTimerNotificationScheduler.identifier(for:))
        super.init()
        migrateStateIfNeeded(from: migrationKeyPrefix)
        restore()
    }

    deinit { timer?.invalidate() }

    static func remaining(until endDate: Date, now: Date) -> Int {
        max(0, Int(ceil(endDate.timeIntervalSince(now))))
    }

    static func clearPersistedState(
        defaults: UserDefaults = .standard,
        keyPrefix: String
    ) {
        ["endDate", "pausedRemaining", "originalDuration", "isPaused", "didComplete"].forEach {
            defaults.removeObject(forKey: "\(keyPrefix).\($0)")
        }
    }

    static func persistedActivityState(
        defaults: UserDefaults = .standard,
        keyPrefix: String,
        now: Date = Date()
    ) -> ActivityState {
        if defaults.bool(forKey: "\(keyPrefix).isPaused") {
            return ActivityState(
                deadline: nil,
                pausedSeconds: max(0, defaults.integer(forKey: "\(keyPrefix).pausedRemaining")),
                didComplete: false
            )
        }
        if let deadline = defaults.object(forKey: "\(keyPrefix).endDate") as? Date {
            if remaining(until: deadline, now: now) > 0 {
                return ActivityState(deadline: deadline, pausedSeconds: 0, didComplete: false)
            }
            return ActivityState(deadline: nil, pausedSeconds: 0, didComplete: true)
        }
        return ActivityState(
            deadline: nil,
            pausedSeconds: 0,
            didComplete: defaults.bool(forKey: "\(keyPrefix).didComplete")
        )
    }

    func start(duration: Int, now: Date = Date()) {
        guard duration > 0 else {
            cancel()
            return
        }
        originalDuration = duration
        pausedRemaining = 0
        didComplete = false
        defaults.removeObject(forKey: "\(keyPrefix).didComplete")
        endDate = now.addingTimeInterval(TimeInterval(duration))
        remainingSeconds = duration
        isRunning = true
        isPaused = false
        stateRevision += 1
        persist()
        scheduleCompletionNotification()
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
        cancelCompletionNotification()
        stateRevision += 1
        persist()
    }

    func resume(now: Date = Date()) {
        guard isPaused, pausedRemaining > 0 else { return }
        endDate = now.addingTimeInterval(TimeInterval(pausedRemaining))
        remainingSeconds = pausedRemaining
        isRunning = true
        isPaused = false
        stateRevision += 1
        persist()
        scheduleCompletionNotification()
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
        didComplete = false
        stateRevision += 1
        cancelCompletionNotification()
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
        stateRevision += 1
        persist()
        if isRunning { scheduleCompletionNotification() }
    }

    func skip() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        pausedRemaining = 0
        remainingSeconds = 0
        isRunning = false
        isPaused = false
        didComplete = true
        stateRevision += 1
        cancelCompletionNotification()
        clearTimerPersistence()
        defaults.set(originalDuration, forKey: "\(keyPrefix).originalDuration")
        defaults.set(true, forKey: "\(keyPrefix).didComplete")
    }

    func dismissCompletion() { cancel() }

    func reload(now: Date = Date()) {
        timer?.invalidate()
        timer = nil
        endDate = nil
        pausedRemaining = 0
        remainingSeconds = 0
        isRunning = false
        isPaused = false
        didComplete = false
        restore(now: now)
        stateRevision += 1
    }

    func setNotificationSoundEnabled(_ enabled: Bool) {
        guard notificationSoundEnabled != enabled else { return }
        notificationSoundEnabled = enabled
        if isRunning {
            scheduleCompletionNotification()
        }
    }

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
        didComplete = true
        stateRevision += 1
        clearTimerPersistence()
        defaults.set(originalDuration, forKey: "\(keyPrefix).originalDuration")
        defaults.set(true, forKey: "\(keyPrefix).didComplete")
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
        didComplete = defaults.bool(forKey: "\(keyPrefix).didComplete")
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
                scheduleCompletionNotification()
                scheduleTimer()
            } else {
                didComplete = true
                clearTimerPersistence()
                defaults.set(originalDuration, forKey: "\(keyPrefix).originalDuration")
                defaults.set(true, forKey: "\(keyPrefix).didComplete")
            }
        }
    }

    private func clearPersistence() {
        clearTimerPersistence()
        defaults.removeObject(forKey: "\(keyPrefix).didComplete")
    }

    private func clearTimerPersistence() {
        ["endDate", "pausedRemaining", "originalDuration", "isPaused"].forEach {
            defaults.removeObject(forKey: "\(keyPrefix).\($0)")
        }
    }

    private func migrateStateIfNeeded(from oldPrefix: String?) {
        guard let oldPrefix, oldPrefix != keyPrefix else { return }
        let suffixes = ["endDate", "pausedRemaining", "originalDuration", "isPaused", "didComplete"]
        let alreadyHasState = suffixes.contains {
            defaults.object(forKey: "\(keyPrefix).\($0)") != nil
        }
        guard !alreadyHasState else { return }

        for suffix in suffixes {
            let oldKey = "\(oldPrefix).\(suffix)"
            if let value = defaults.object(forKey: oldKey) {
                defaults.set(value, forKey: "\(keyPrefix).\(suffix)")
                defaults.removeObject(forKey: oldKey)
            }
        }
    }

    private func scheduleCompletionNotification() {
        guard let endDate, let notificationIdentifier else { return }
        notificationScheduler?.schedule(RestTimerNotificationPlan(
            identifier: notificationIdentifier,
            endDate: endDate,
            soundEnabled: notificationSoundEnabled
        ))
    }

    private func cancelCompletionNotification() {
        guard let notificationIdentifier else { return }
        notificationScheduler?.cancel(identifier: notificationIdentifier)
    }
}
