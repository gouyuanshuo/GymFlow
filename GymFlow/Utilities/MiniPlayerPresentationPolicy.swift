enum MiniPlayerPresentationPolicy {
    static func showsGlobalPlayer(
        hasLoadedTrack: Bool,
        isWorkoutPresented: Bool,
        isNowPlayingPresented: Bool = false
    ) -> Bool {
        hasLoadedTrack && !isWorkoutPresented && !isNowPlayingPresented
    }

    static func showsWorkoutPlayer(
        hasLoadedTrack: Bool,
        isWorkoutPresented: Bool,
        isNowPlayingPresented: Bool = false
    ) -> Bool {
        hasLoadedTrack && isWorkoutPresented && !isNowPlayingPresented
    }
}

struct NowPlayingPresentationState: Equatable {
    private(set) var isPresented = false

    mutating func present() {
        isPresented = true
    }

    mutating func updateSystemPresentation(_ isPresented: Bool) {
        self.isPresented = isPresented
    }
}
