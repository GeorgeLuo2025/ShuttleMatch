import Foundation

struct Game: Identifiable, Codable {
    var id: String = UUID().uuidString
    var matchID: String
    var round: Int
    var playerAIDs: [String]
    var playerBIDs: [String]
    var scores: [GameScore] = []
    var status: GameStatus = .pending

    var teamMatchSlotID: String?
}

struct GameScore: Codable, Hashable {
    var playerAScore: Int
    var playerBScore: Int
}

enum GameStatus: String, Codable {
    case pending
    case inProgress
    case completed
}

struct LeaderboardEntry: Identifiable {
    var id: String { playerID }
    var playerID: String
    var playerName: String
    var wins: Int = 0
    var losses: Int = 0
    var gamesWon: Int = 0
    var gamesLost: Int = 0

    var winRate: Double {
        let total = wins + losses
        return total > 0 ? Double(wins) / Double(total) : 0
    }

    var netGames: Int {
        gamesWon - gamesLost
    }
}
