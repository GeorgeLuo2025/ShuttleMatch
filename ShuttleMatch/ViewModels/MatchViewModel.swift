import Foundation
import Combine
import FirebaseAuth

@MainActor
class MatchViewModel: ObservableObject {
    @Published var matches: [Match] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var currentMatch: Match?
    @Published var games: [Game] = []
    @Published var players: [Player] = []
    @Published var leaderboard: [LeaderboardEntry] = []

    @Published var searchResults: [Player] = []

    private let service = FirestoreService.shared

    var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    func loadMatches() async {
        guard let uid = currentUserID else { return }
        isLoading = true
        do {
            matches = try await service.getMatchesForUser(userID: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createMatch(name: String, type: MatchType, rounds: Int, scoringRule: ScoringRule,
                     teamAName: String? = nil, teamBName: String? = nil,
                     teamMatchSlots: [TeamMatchSlot]? = nil) async -> Match? {
        guard let uid = currentUserID else { return nil }

        var match = Match(
            name: name,
            type: type,
            scoringRule: scoringRule,
            organizerID: uid,
            rounds: rounds
        )

        if type == .team, let aName = teamAName, let bName = teamBName {
            match.teamA = TeamInfo(name: aName, captainID: uid, memberIDs: [])
            match.teamB = TeamInfo(name: bName, captainID: "", memberIDs: [])
            match.teamMatchSlots = teamMatchSlots
        }

        do {
            try await service.createMatch(match)
            matches.insert(match, at: 0)
            return match
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func loadMatchDetail(matchID: String) async {
        isLoading = true
        do {
            currentMatch = try await service.getMatch(id: matchID)
            if let match = currentMatch {
                players = try await service.getPlayers(ids: match.playerIDs)
                games = try await service.getGames(matchID: match.id)
                computeLeaderboard()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func searchUsers(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        do {
            searchResults = try await service.searchPlayers(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addPlayer(playerID: String) async {
        guard let match = currentMatch else { return }
        do {
            try await service.addPlayerToMatch(matchID: match.id, playerID: playerID)
            currentMatch?.playerIDs.append(playerID)
            if let player = try await service.getPlayer(id: playerID) {
                players.append(player)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removePlayer(playerID: String) async {
        guard let match = currentMatch else { return }
        do {
            try await service.removePlayerFromMatch(matchID: match.id, playerID: playerID)
            currentMatch?.playerIDs.removeAll { $0 == playerID }
            players.removeAll { $0.id == playerID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateMatchups() async {
        guard var match = currentMatch else { return }
        let playerIDs = match.playerIDs

        guard playerIDs.count >= 2 else {
            errorMessage = String(localized: "min_players_error")
            return
        }

        var allGames: [Game] = []
        let rounds = match.rounds

        let n = playerIDs.count
        var ids = playerIDs
        let hasBye = n % 2 != 0
        if hasBye {
            ids.append("BYE")
        }
        let total = ids.count

        for round in 0..<rounds {
            let roundIndex = round % (total - 1)

            var rotated = [ids[0]]
            for i in 1..<total {
                let idx = (i - 1 + roundIndex) % (total - 1) + 1
                rotated.append(ids[idx])
            }

            for i in 0..<(total / 2) {
                let a = rotated[i]
                let b = rotated[total - 1 - i]

                if a == "BYE" || b == "BYE" { continue }

                let game = Game(
                    matchID: match.id,
                    round: round + 1,
                    playerAIDs: [a],
                    playerBIDs: [b]
                )
                allGames.append(game)
            }
        }

        do {
            try await service.createGames(allGames)
            match.status = .ongoing
            try await service.updateMatch(match)
            currentMatch = match
            games = allGames
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveScoreDraft(game: Game, scores: [GameScore]) async {
        do {
            try await service.updateGameScores(gameID: game.id, scores: scores, status: .inProgress)
            if let index = games.firstIndex(where: { $0.id == game.id }) {
                games[index].scores = scores
                games[index].status = .inProgress
            }
            computeLeaderboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmGameComplete(game: Game, scores: [GameScore]) async -> Bool {
        let rule = currentMatch?.scoringRule ?? .standard

        if let validationError = validateScores(scores: scores, rule: rule) {
            errorMessage = validationError
            return false
        }

        do {
            try await service.updateGameScores(gameID: game.id, scores: scores, status: .completed)
            if let index = games.firstIndex(where: { $0.id == game.id }) {
                games[index].scores = scores
                games[index].status = .completed
            }
            computeLeaderboard()

            if games.allSatisfy({ $0.status == .completed }) {
                currentMatch?.status = .finished
                if let match = currentMatch {
                    try await service.updateMatch(match)
                }
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func validateScores(scores: [GameScore], rule: ScoringRule) -> String? {
        guard !scores.isEmpty else {
            return String(localized: "enter_score_error")
        }

        let winsNeeded = rule.gamesPerMatch / 2 + 1
        var aWins = 0, bWins = 0

        for (i, score) in scores.enumerated() {
            if let err = validateSingleGame(score: score, rule: rule, gameNumber: i + 1) {
                return err
            }
            if score.playerAScore > score.playerBScore {
                aWins += 1
            } else {
                bWins += 1
            }
        }

        if aWins < winsNeeded && bWins < winsNeeded {
            return "比赛尚未分出胜负，需要一方赢得 \(winsNeeded) 局"
        }

        return nil
    }

    private func validateSingleGame(score: GameScore, rule: ScoringRule, gameNumber: Int) -> String? {
        let a = score.playerAScore
        let b = score.playerBScore
        let target = rule.pointsPerGame

        if a == b {
            return "第 \(gameNumber) 局比分不能相同"
        }

        let winner = max(a, b)
        let loser = min(a, b)

        if rule.deuceEnabled {
            let cap = rule.deuceCapPoints ?? (target + 9)

            if loser < target - 1 {
                if winner != target {
                    return "第 \(gameNumber) 局：非平分情况下，赢方应为 \(target) 分"
                }
            } else {
                if winner == cap {
                    if loser < cap - 2 {
                        return "第 \(gameNumber) 局：封顶分 \(cap) 时，输方至少 \(cap - 2) 分"
                    }
                } else if winner - loser != 2 {
                    return "第 \(gameNumber) 局：Deuce 后需领先2分才能获胜"
                }
            }
        } else {
            if winner != target {
                return "第 \(gameNumber) 局：赢方应为 \(target) 分"
            }
        }

        return nil
    }

    func isGameSetComplete(score: GameScore, rule: ScoringRule) -> Bool {
        return validateSingleGame(score: score, rule: rule, gameNumber: 1) == nil
            && score.playerAScore != score.playerBScore
    }

    func hasMatchWinner(scores: [GameScore], rule: ScoringRule) -> Bool {
        let winsNeeded = rule.gamesPerMatch / 2 + 1
        var aWins = 0, bWins = 0
        for score in scores {
            if score.playerAScore > score.playerBScore { aWins += 1 }
            else if score.playerBScore > score.playerAScore { bWins += 1 }
        }
        return aWins >= winsNeeded || bWins >= winsNeeded
    }

    func computeLeaderboard() {
        guard let match = currentMatch else { return }
        var entries: [String: LeaderboardEntry] = [:]

        for player in players {
            entries[player.id] = LeaderboardEntry(
                playerID: player.id,
                playerName: player.displayName
            )
        }

        for game in games where game.status == .completed {
            let rule = match.scoringRule
            let winsNeeded = rule.gamesPerMatch / 2 + 1
            var aGameWins = 0, bGameWins = 0

            for score in game.scores {
                if score.playerAScore > score.playerBScore {
                    aGameWins += 1
                } else {
                    bGameWins += 1
                }
            }

            let aWon = aGameWins >= winsNeeded

            for pid in game.playerAIDs {
                if aWon {
                    entries[pid]?.wins += 1
                } else {
                    entries[pid]?.losses += 1
                }
                entries[pid]?.gamesWon += aGameWins
                entries[pid]?.gamesLost += bGameWins
            }

            for pid in game.playerBIDs {
                if aWon {
                    entries[pid]?.losses += 1
                } else {
                    entries[pid]?.wins += 1
                }
                entries[pid]?.gamesWon += bGameWins
                entries[pid]?.gamesLost += aGameWins
            }
        }

        leaderboard = Array(entries.values).sorted { a, b in
            if a.wins != b.wins { return a.wins > b.wins }
            return a.netGames > b.netGames
        }
    }
}
