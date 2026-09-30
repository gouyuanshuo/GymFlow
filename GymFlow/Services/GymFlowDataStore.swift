import SwiftData

enum GymFlowDataStore {
    static let schema = Schema(versionedSchema: GymFlowSchemaV1.self)

    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: GymFlowMigrationPlan.self
        )
    }

    /// Configuration injection is reserved for deterministic in-memory and on-disk store tests.
    static func makeContainer(
        configurations: [ModelConfiguration]
    ) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: GymFlowMigrationPlan.self,
            configurations: configurations
        )
    }
}
