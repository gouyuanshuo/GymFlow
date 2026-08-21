import Combine
import Foundation

/// The between-sets rest countdown for one workout.
///
/// The timer must keep running across app suspension and relaunch, so every state change is
/// mirrored into `UserDefaults` under a per-session prefix (see ``RestTimerStorage``) and restored
/// on init. A local notification is scheduled alongside it so the user is alerted even when the app
/// is not in the foreground.
@MainActor
final class RestTimerService: ObservableObject {
    struct ActivityState: Equatable {
        let deadline: Date?
        let pausedSeconds: Int
        let didComplete: Bool
    }

    /// How much a single "+30s" tap adds.
    private static let extensionSeconds = 30
    /// The countdown is displayed in whole seconds, so it is sampled several times a second to keep
    /// the displayed value from lagging behind the clock by up to a full second.
    private static let tickInterval: TimeInterval = 0.25

    @Published private(set) var remainingSeconds = 0
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var didComplete = false
    /// Bumped on every state change so views can observe "something happened" without comparing
    /// each published property.
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
        keyPrefix: String = RestTimerStorage.legacyKeyPrefix,
        migrationKeyPrefix: String? = nil,
        sessionID: UUID? = nil,
        notificationScheduler: RestTimerNotificationScheduling? = nil
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        self.notificationScheduler = notificationScheduler
        self.notificationIdentifier = sessionID.map(RestTimerNotificationScheduler.identifier(for:))
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
        for field in RestTimerStorage.Field.allCases {
            defaults.removeObject(forKey: RestTimerStorage.key(field, prefix: keyPrefix))
        }
    }

    /// Reads a timer's state without instantiating one, for the widget and Live Activity.
    static func persistedActivityState(
        defaults: UserDefaults = .standard,
        keyPrefix: String,
        now: Date = Date()
    ) -> ActivityState {
        func key(_ field: RestTimerStorage.Field) -> String {
            RestTimerStorage.key(field, prefix: keyPrefix)
        }

        if defaults.bool(forKey: key(.isPaused)) {
            return ActivityState(
                deadline: nil,
                pausedSeconds: max(0, defaults.integer(forKey: key(.pausedRemaining))),
                didComplete: false
            )
        }
        if let deadline = defaults.object(forKey: key(.endDate)) as? Date {
            if remaining(until: deadline, now: now) > 0 {
                return ActivityState(deadline: deadline, pausedSeconds: 0, didComplete: false)
            }
            return ActivityState(deadline: nil, pausedSeconds: 0, didComplete: true)
        }
        return ActivityState(
            deadline: nil,
            pausedSeconds: 0,
            didComplete: defaults.bool(forKey: key(.didComplete))
        )
    }

    // MARK: - Controls

    func start(duration: Int, now: Date = Date()) {
        guard duration > 0 else {
            cancel()
            return
        }
        originalDuration = duration
        pausedRemaining = 0
        didComplete = false
        defaults.removeObject(forKey: key(.didComplete))
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

    /// Stops the timer and forgets it ever ran.
    func cancel() {
        stopCountdown()
        didComplete = false
        stateRevision += 1
        cancelCompletionNotification()
        Self.clearPersistedState(defaults: defaults, keyPrefix: keyPrefix)
    }

    func restart(now: Date = Date()) {
        guard originalDuration > 0 else { return }
        start(duration: originalDuration, now: now)
    }

    /// Extends the rest by 30 seconds, starting a fresh rest if none is under way.
    func addThirtySeconds(now: Date = Date()) {
        if isRunning, let endDate {
            let extended = endDate.addingTimeInterval(TimeInterval(Self.extensionSeconds))
            self.endDate = extended
            remainingSeconds = Self.remaining(until: extended, now: now)
        } else if isPaused {
            pausedRemaining += Self.extensionSeconds
            remainingSeconds = pausedRemaining
        } else {
            originalDuration = max(Self.extensionSeconds, originalDuration + Self.extensionSeconds)
            start(duration: originalDuration, now: now)
            return
        }
        stateRevision += 1
        persist()
        if isRunning { scheduleCompletionNotification() }
    }

    /// Ends the rest early, treating it as finished.
    func skip() {
        markFinished()
        // The user is already moving on, so the alert that was queued for the deadline is unwanted.
        cancelCompletionNotification()
    }

    func dismissCompletion() { cancel() }

    /// Re-reads persisted state, for when the app returns to the foreground.
    func reload(now: Date = Date()) {
        stopCountdown()
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

    /// Recomputes the remaining time against the clock, completing the timer if it has run out.
    ///
    /// The countdown is derived from a deadline rather than accumulated ticks, so this stays correct
    /// no matter how long the app spent suspended.
    func refresh(now: Date = Date()) {
        guard isRunning, let endDate else { return }
        let remaining = Self.remaining(until: endDate, now: now)
        remainingSeconds = remaining
        if remaining == 0 { complete() }
    }

    // MARK: - Countdown

    private func scheduleTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // `.common` so the countdown keeps ticking while a scroll view is being dragged.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Tears the countdown down without deciding whether it completed or was abandoned.
    private func stopCountdown() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        pausedRemaining = 0
        remainingSeconds = 0
        isRunning = false
        isPaused = false
    }

    private func complete() {
        markFinished()
        // The scheduled notification is deliberately left alone: it is due at this same instant and
        // cancelling it here could race the system into suppressing an alert the user should get.
        onCompletion?()
    }

    /// Records that the rest is over, whether it ran out or the user skipped it.
    ///
    /// `didComplete` and the original duration outlive the countdown so the UI can still show the
    /// completion banner and offer to repeat the same rest afterwards.
    private func markFinished() {
        stopCountdown()
        didComplete = true
        stateRevision += 1
        clearCountdownPersistence()
        defaults.set(originalDuration, forKey: key(.originalDuration))
        defaults.set(true, forKey: key(.didComplete))
    }

    // MARK: - Persistence

    private func key(_ field: RestTimerStorage.Field) -> String {
        RestTimerStorage.key(field, prefix: keyPrefix)
    }

    private func persist() {
        defaults.set(endDate, forKey: key(.endDate))
        defaults.set(pausedRemaining, forKey: key(.pausedRemaining))
        defaults.set(originalDuration, forKey: key(.originalDuration))
        defaults.set(isPaused, forKey: key(.isPaused))
    }

    private func restore(now: Date = Date()) {
        originalDuration = defaults.integer(forKey: key(.originalDuration))
        didComplete = defaults.bool(forKey: key(.didComplete))

        if defaults.bool(forKey: key(.isPaused)) {
            pausedRemaining = defaults.integer(forKey: key(.pausedRemaining))
            remainingSeconds = pausedRemaining
            isPaused = pausedRemaining > 0
            return
        }

        guard let storedEndDate = defaults.object(forKey: key(.endDate)) as? Date else { return }
        let remaining = Self.remaining(until: storedEndDate, now: now)
        guard remaining > 0 else {
            // The rest ran out while the app was away, so surface it as already completed.
            markFinished()
            return
        }
        endDate = storedEndDate
        remainingSeconds = remaining
        isRunning = true
        scheduleCompletionNotification()
        scheduleTimer()
    }

    private func clearCountdownPersistence() {
        for field in RestTimerStorage.Field.countdown {
            defaults.removeObject(forKey: key(field))
        }
    }

    /// Moves state written under an older key prefix onto this timer's prefix.
    ///
    /// Rest timers used to be app-wide rather than per-session, so a workout resumed across the
    /// upgrade would otherwise lose its running rest.
    private func migrateStateIfNeeded(from oldPrefix: String?) {
        guard let oldPrefix, oldPrefix != keyPrefix else { return }
        let alreadyHasState = RestTimerStorage.Field.allCases.contains {
            defaults.object(forKey: key($0)) != nil
        }
        guard !alreadyHasState else { return }

        for field in RestTimerStorage.Field.allCases {
            let oldKey = RestTimerStorage.key(field, prefix: oldPrefix)
            if let value = defaults.object(forKey: oldKey) {
                defaults.set(value, forKey: key(field))
                defaults.removeObject(forKey: oldKey)
            }
        }
    }

    // MARK: - Notifications

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
