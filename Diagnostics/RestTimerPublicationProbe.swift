import Combine
import Foundation

/// Standalone probe against the real rest service; uses isolated defaults, never the app store.
@main
@MainActor
enum RestTimerPublicationProbe {
    static func main() {
        let suite = "GymFlow.RestTimerPublicationProbe.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            preconditionFailure("Could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let timer = RestTimerService(defaults: defaults, keyPrefix: "probe")
        var publications = 0
        let observation = timer.$remainingSeconds.sink { _ in publications += 1 }
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        timer.start(duration: 10, now: start)
        publications = 0
        for offset in [0.1, 0.35, 0.6] {
            timer.refresh(now: start.addingTimeInterval(offset))
        }
        print("unchanged-second publications: \(publications) / 3 refreshes")
        if CommandLine.arguments.contains("--assert-optimized") {
            precondition(publications == 0, "Unchanged visible seconds must not publish")
        }

        timer.refresh(now: start.addingTimeInterval(1.1))
        print("publications after one visible second change: \(publications)")
        if CommandLine.arguments.contains("--assert-optimized") {
            precondition(publications == 1, "A changed visible second must publish once")
        }

        timer.pause(now: start.addingTimeInterval(1.2))
        precondition(timer.isPaused && timer.remainingSeconds == 9)
        timer.addThirtySeconds(now: start.addingTimeInterval(1.2))
        precondition(timer.remainingSeconds == 39)
        timer.resume(now: start.addingTimeInterval(5))
        precondition(timer.isRunning && timer.deadline == start.addingTimeInterval(44))
        timer.reload(now: start.addingTimeInterval(15))
        precondition(timer.isRunning && timer.remainingSeconds == 29)
        timer.skip()
        precondition(timer.didComplete && !timer.isRunning && timer.remainingSeconds == 0)
        print("pause, +30, resume, persisted reload, skip: passed")
        timer.cancel()
        withExtendedLifetime(observation) {}
    }
}
