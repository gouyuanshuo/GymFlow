import AppIntents
import Foundation

@available(iOS 17.0, *)
@MainActor
enum WorkoutActivityIntentBridge {
    typealias CompleteHandler = @MainActor (UUID, UUID, Date) async -> Void
    typealias TimerHandler = @MainActor (UUID, Date) async -> Void

    private static var completeHandler: CompleteHandler?
    private static var addThirtySecondsHandler: TimerHandler?
    private static var skipRestHandler: TimerHandler?

    static func install(
        complete: @escaping CompleteHandler,
        addThirtySeconds: @escaping TimerHandler,
        skipRest: @escaping TimerHandler
    ) {
        completeHandler = complete
        addThirtySecondsHandler = addThirtySeconds
        skipRestHandler = skipRest
    }

    static func completeCurrentSet(
        sessionID: UUID,
        setID: UUID,
        now: Date = Date()
    ) async {
        await completeHandler?(sessionID, setID, now)
    }

    static func addThirtySeconds(sessionID: UUID, now: Date = Date()) async {
        await addThirtySecondsHandler?(sessionID, now)
    }

    static func skipRest(sessionID: UUID, now: Date = Date()) async {
        await skipRestHandler?(sessionID, now)
    }
}

@available(iOS 17.0, *)
struct CompleteCurrentSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Current Set"
    static var description = IntentDescription(
        "Completes the set currently shown by GymFlow and starts its rest timer."
    )
    // This is the least restrictive App Intent policy. WidgetKit still requires
    // device authentication before any third-party locked Live Activity control runs.
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Workout")
    var sessionIdentifier: String

    @Parameter(title: "Set")
    var setIdentifier: String

    init() {
        sessionIdentifier = ""
        setIdentifier = ""
    }

    init(sessionID: UUID, setID: UUID) {
        sessionIdentifier = sessionID.uuidString
        setIdentifier = setID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let sessionID = UUID(uuidString: sessionIdentifier),
              let setID = UUID(uuidString: setIdentifier) else {
            return .result()
        }
        await WorkoutActivityIntentBridge.completeCurrentSet(
            sessionID: sessionID,
            setID: setID
        )
        return .result()
    }
}

@available(iOS 17.0, *)
struct AddThirtySecondsRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Add 30 Seconds"
    static var description = IntentDescription("Adds 30 seconds to GymFlow's active rest timer.")
    // WidgetKit's locked-device authentication remains authoritative.
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Workout")
    var sessionIdentifier: String

    init() {
        sessionIdentifier = ""
    }

    init(sessionID: UUID) {
        sessionIdentifier = sessionID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let sessionID = UUID(uuidString: sessionIdentifier) else {
            return .result()
        }
        await WorkoutActivityIntentBridge.addThirtySeconds(sessionID: sessionID)
        return .result()
    }
}

@available(iOS 17.0, *)
struct SkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip Rest"
    static var description = IntentDescription("Skips GymFlow's active rest timer.")
    // WidgetKit's locked-device authentication remains authoritative.
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Workout")
    var sessionIdentifier: String

    init() {
        sessionIdentifier = ""
    }

    init(sessionID: UUID) {
        sessionIdentifier = sessionID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let sessionID = UUID(uuidString: sessionIdentifier) else {
            return .result()
        }
        await WorkoutActivityIntentBridge.skipRest(sessionID: sessionID)
        return .result()
    }
}
