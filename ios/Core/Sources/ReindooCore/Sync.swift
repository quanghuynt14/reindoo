import Foundation

public enum SyncError: Error, Equatable, Sendable {
    /// Pas de réseau, serveur injoignable, 5xx : on réessaiera.
    case unavailable
    /// Le serveur ne veut pas de ce changement : réessayer n'y changera rien.
    case rejected(String)
}

/// Ce que Core attend du réseau. L'app fournira une implémentation HTTP ;
/// les tests et le CLI fournissent un serveur de fixture.
public protocol SyncClient: Sendable {
    func push(_ change: Change) async throws(SyncError)
}

public enum SyncOutcome: Equatable, Sendable {
    case upToDate
    case sent(Int)
    /// Arrêté par une coupure : `sent` sont partis, le reste attend.
    case interrupted(sent: Int)
}

/// Vide la file, le plus ancien d'abord. S'arrête à la première coupure, pour
/// garder l'ordre. Ne bloque jamais l'écran : l'app lit toujours la base locale.
@MainActor
public final class Syncer {
    private let store: UserStore
    private let client: any SyncClient
    private var running = false

    public init(store: UserStore, client: any SyncClient) {
        self.store = store
        self.client = client
    }

    @discardableResult
    public func drain() async throws -> SyncOutcome {
        guard !running else { return .upToDate }
        running = true
        defer { running = false }

        var sent = 0
        while let change = try store.pendingChanges().first {
            let failure: SyncError?
            do throws(SyncError) {
                try await client.push(change)
                failure = nil
            } catch {
                failure = error
            }

            switch failure {
            case nil:
                try store.acknowledge(change.id)
                sent += 1
            case .unavailable:
                return .interrupted(sent: sent)
            case .rejected(let reason):
                try store.park(change.id, reason: reason)
            }
        }
        return sent == 0 ? .upToDate : .sent(sent)
    }
}
