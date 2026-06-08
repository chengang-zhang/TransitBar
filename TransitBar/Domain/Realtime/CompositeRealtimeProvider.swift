import Foundation

nonisolated struct CompositeRealtimeProvider: RealtimeProvider {
    let providers: [any RealtimeProvider]

    func tripUpdates() async throws -> [RealtimeTripUpdate] {
        try await values { provider in
            try await provider.tripUpdates()
        }
    }

    func alerts() async throws -> [RealtimeAlert] {
        try await values { provider in
            try await provider.alerts()
        }
    }

    func vehiclePositions() async throws -> [RealtimeVehiclePosition] {
        try await values { provider in
            try await provider.vehiclePositions()
        }
    }

    private func values<Value: Sendable>(
        fetch: (any RealtimeProvider) async throws -> [Value]
    ) async throws -> [Value] {
        var combined: [Value] = []
        var firstError: Error?
        var didReceiveResponse = false

        for provider in providers {
            do {
                combined.append(contentsOf: try await fetch(provider))
                didReceiveResponse = true
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }

        if didReceiveResponse {
            return combined
        }

        throw firstError ?? CompositeRealtimeProviderError.noProviders
    }
}

nonisolated private enum CompositeRealtimeProviderError: Error {
    case noProviders
}
