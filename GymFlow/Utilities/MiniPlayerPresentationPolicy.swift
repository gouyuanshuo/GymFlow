enum MiniPlayerPresentationPolicy {
    static func showsGlobalPlayer(
        hasLoadedTrack: Bool,
        isWorkoutPresented: Bool
    ) -> Bool {
        hasLoadedTrack && !isWorkoutPresented
    }

    static func showsWorkoutPlayer(
        hasLoadedTrack: Bool,
        isWorkoutPresented: Bool
    ) -> Bool {
        hasLoadedTrack && isWorkoutPresented
    }
}
