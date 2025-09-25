import Foundation
import DiContainer
import LogMacro

// MARK: - 운영 패턴 1: 회복/폴백

protocol RemoteConfig: Sendable { func fetch() async throws -> String }
struct FailingRemoteConfig: RemoteConfig {
    func fetch() async throws -> String { throw URLError(.timedOut) }
}
struct LocalFallbackConfig: RemoteConfig { func fetch() async throws -> String { "LOCAL_FALLBACK" } }

enum ResilientRemoteConfig {
    static func load(primary: RemoteConfig, fallback: RemoteConfig) async -> String {
        do { return try await primary.fetch() }
        catch {
            #logWarning("⚠️ [Ops] primary failed: \(error). using fallback…")
            return (try? await fallback.fetch()) ?? "DEFAULT"
        }
    }
}
