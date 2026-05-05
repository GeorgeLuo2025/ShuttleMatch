import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    func savePlayer(_ player: Player) async throws {
        try db.collection("players").document(player.id).setData(from: player)
    }

    func getPlayer(id: String) async throws -> Player? {
        let doc = try await db.collection("players").document(id).getDocument()
        return try? doc.data(as: Player.self)
    }

    func searchPlayers(query: String) async throws -> [Player] {
        let end = query + "\u{f8ff}"
        let snapshot = try await db.collection("players")
            .whereField("displayName", isGreaterThanOrEqualTo: query)
            .whereField("displayName", isLessThan: end)
            .limit(to: 20)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Player.self) }
    }

    func getPlayers(ids: [String]) async throws -> [Player] {
        guard !ids.isEmpty else { return [] }
        var players: [Player] = []
        for chunk in ids.chunked(into: 30) {
            let snapshot = try await db.collection("players")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            players += snapshot.documents.compactMap { try? $0.data(as: Player.self) }
        }
        return players
    }

    func createMatch(_ match: Match) async throws {
        try db.collection("matches").document(match.id).setData(from: match)
    }

    func updateMatch(_ match: Match) async throws {
        try db.collection("matches").document(match.id).setData(from: match, merge: true)
    }

    func getMatchesForUser(userID: String) async throws -> [Match] {
        let organizedSnapshot = try await db.collection("matches")
            .whereField("organizerID", isEqualTo: userID)
            .getDocuments()

        let joinedSnapshot = try await db.collection("matches")
            .whereField("playerIDs", arrayContains: userID)
            .getDocuments()

        var matchMap: [String: Match] = [:]
        for doc in organizedSnapshot.documents + joinedSnapshot.documents {
            if let match = try? doc.data(as: Match.self) {
                matchMap[match.id] = match
            }
        }
        return Array(matchMap.values).sorted { $0.createdAt > $1.createdAt }
    }

    func getMatch(id: String) async throws -> Match? {
        let doc = try await db.collection("matches").document(id).getDocument()
        return try? doc.data(as: Match.self)
    }

    func addPlayerToMatch(matchID: String, playerID: String) async throws {
        try await db.collection("matches").document(matchID).updateData([
            "playerIDs": FieldValue.arrayUnion([playerID])
        ])
    }

    func removePlayerFromMatch(matchID: String, playerID: String) async throws {
        try await db.collection("matches").document(matchID).updateData([
            "playerIDs": FieldValue.arrayRemove([playerID])
        ])
    }

    func deleteMatch(id: String) async throws {
        try await db.collection("matches").document(id).delete()
    }

    func createGames(_ games: [Game]) async throws {
        let batch = db.batch()
        for game in games {
            let ref = db.collection("games").document(game.id)
            try batch.setData(from: game, forDocument: ref)
        }
        try await batch.commit()
    }

    func getGames(matchID: String) async throws -> [Game] {
        let snapshot = try await db.collection("games")
            .whereField("matchID", isEqualTo: matchID)
            .getDocuments()
        return snapshot.documents
            .compactMap { try? $0.data(as: Game.self) }
            .sorted { $0.round < $1.round }
    }

    func updateGameScores(gameID: String, scores: [GameScore], status: GameStatus) async throws {
        try await db.collection("games").document(gameID).updateData([
            "scores": scores.map { ["playerAScore": $0.playerAScore, "playerBScore": $0.playerBScore] },
            "status": status.rawValue
        ])
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
