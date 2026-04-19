import Foundation

enum MatchType: String, Codable, CaseIterable {
    case individualSingles = "individual_singles"
    case individualDoubles = "individual_doubles"
    case team = "team"

}

enum MatchStatus: String, Codable {
    case registration
    case ongoing
    case finished
}

struct ScoringRule: Codable, Hashable, Equatable {
    var pointsPerGame: Int
    var gamesPerMatch: Int
    var deuceEnabled: Bool
    var deuceCapPoints: Int?

    static let standard = ScoringRule(
        pointsPerGame: 21,
        gamesPerMatch: 3,
        deuceEnabled: true,
        deuceCapPoints: 30
    )
}

struct Match: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var type: MatchType
    var status: MatchStatus = .registration
    var scoringRule: ScoringRule = .standard
    var organizerID: String
    var playerIDs: [String] = []
    var rounds: Int = 0
    var createdAt: Date = Date()

    var teamA: TeamInfo?
    var teamB: TeamInfo?
    var teamMatchSlots: [TeamMatchSlot]?
    var targetScore: Int?
}

struct TeamInfo: Codable, Hashable {
    var name: String
    var captainID: String
    var memberIDs: [String] = []
}

struct TeamMatchSlot: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var slotType: SlotType
    var slotOrder: Int
    var teamAPlayerIDs: [String] = []
    var teamBPlayerIDs: [String] = []
}

enum SlotType: String, Codable, Hashable {
    case singles
    case doubles
}
