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

    // MARK: - Match CRUD

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
        } else if type == .team {
            // Default empty team info so we can populate later
            match.teamA = TeamInfo(name: "", captainID: uid, memberIDs: [])
            match.teamB = TeamInfo(name: "", captainID: "", memberIDs: [])
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

    // MARK: - Generate Matchups (dispatcher)

    func generateMatchups() async {
        guard var match = currentMatch else { return }

        switch match.type {
        case .team:
            await generateTeamMatchups(match: &match)
        case .individualDoubles:
            let games = generateDoublesGames(match: match)
            await commitGames(games, match: &match)
        case .individualSingles:
            let games = generateSinglesGames(match: match)
            await commitGames(games, match: &match)
        }
    }

    private func commitGames(_ allGames: [Game], match: inout Match) async {
        guard !allGames.isEmpty else { return }
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

    // MARK: - Team Match Generation
    //
    // Steps:
    //  1. Randomly shuffle all playerIDs and split evenly: first half → Team A, second half → Team B.
    //  2. Persist the team membership back to Firestore.
    //  3. For each TeamMatchSlot (singles / doubles), assign players from each team
    //     and create one Game per slot.
    //     - Singles slot: 1 player from A vs 1 player from B (cycle through members)
    //     - Doubles slot: 2 players from A vs 2 players from B (cycle through members)

    private func generateTeamMatchups(match: inout Match) async {
        let playerIDs = match.playerIDs

        // Enforce even count (UI already guards this, but double-check here)
        guard playerIDs.count % 2 == 0 else {
            errorMessage = "团队赛需要偶数名球员"
            return
        }
        guard let slots = match.teamMatchSlots, !slots.isEmpty else {
            errorMessage = "请先设置对阵项目（单打/双打场数）"
            return
        }

        // 1. Random split
        let shuffled = playerIDs.shuffled()
        let half = shuffled.count / 2
        let teamAIDs = Array(shuffled[0..<half])
        let teamBIDs = Array(shuffled[half...])

        match.teamA?.memberIDs = teamAIDs
        match.teamB?.memberIDs = teamBIDs

        // 2. Generate one game per slot
        var allGames: [Game] = []

        // We cycle through team members so slots are spread evenly
        var aIndex = 0
        var bIndex = 0

        let sortedSlots = slots.sorted { $0.slotOrder < $1.slotOrder }

        for slot in sortedSlots {
            var teamAPlayers: [String] = []
            var teamBPlayers: [String] = []

            switch slot.slotType {
            case .singles:
                // 1 vs 1
                teamAPlayers = [teamAIDs[aIndex % teamAIDs.count]]
                teamBPlayers = [teamBIDs[bIndex % teamBIDs.count]]
                aIndex += 1
                bIndex += 1

            case .doubles:
                // Need at least 2 per team; if team too small, fall back to singles
                if teamAIDs.count >= 2 && teamBIDs.count >= 2 {
                    let a1 = teamAIDs[aIndex % teamAIDs.count]
                    let a2 = teamAIDs[(aIndex + 1) % teamAIDs.count]
                    let b1 = teamBIDs[bIndex % teamBIDs.count]
                    let b2 = teamBIDs[(bIndex + 1) % teamBIDs.count]
                    teamAPlayers = [a1, a2]
                    teamBPlayers = [b1, b2]
                    aIndex += 2
                    bIndex += 2
                } else {
                    teamAPlayers = [teamAIDs[aIndex % teamAIDs.count]]
                    teamBPlayers = [teamBIDs[bIndex % teamBIDs.count]]
                    aIndex += 1
                    bIndex += 1
                }
            }

            let game = Game(
                matchID: match.id,
                round: slot.slotOrder,
                playerAIDs: teamAPlayers,
                playerBIDs: teamBPlayers,
                teamMatchSlotID: slot.id
            )
            allGames.append(game)
        }

        // 3. Persist everything
        do {
            try await service.updateMatch(match)
            try await service.createGames(allGames)
            match.status = .ongoing
            try await service.updateMatch(match)
            currentMatch = match
            // Refresh players so team sections display correctly
            players = try await service.getPlayers(ids: match.playerIDs)
            games = allGames
            computeLeaderboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Singles League (Round Robin)

    private func generateSinglesGames(match: Match) -> [Game] {
        let playerIDs = match.playerIDs

        guard playerIDs.count >= 2 else {
            errorMessage = String(localized: "min_players_error")
            return []
        }

        var allGames: [Game] = []
        let rounds = match.rounds

        var ids = playerIDs
        if ids.count % 2 != 0 { ids.append("BYE") }
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
                allGames.append(Game(
                    matchID: match.id,
                    round: round + 1,
                    playerAIDs: [a],
                    playerBIDs: [b]
                ))
            }
        }
        return allGames
    }

    // MARK: - Doubles League (Rotating Partners)

    private func generateDoublesGames(match: Match) -> [Game] {
        var playerIDs = match.playerIDs
        let targetGamesPerPlayer = match.rounds

        guard playerIDs.count >= 4 else {
            errorMessage = "双打联赛至少需要4名球员"
            return []
        }

        if playerIDs.count % 2 != 0 { playerIDs.append("BYE") }

        let groups = combinations(of: playerIDs, choosing: 4)

        struct Fixture {
            let teamA: [String]
            let teamB: [String]
            var all4: [String] { teamA + teamB }
        }

        var fixtures: [Fixture] = []
        for group in groups {
            guard !group.contains("BYE") else { continue }
            let splits: [([String], [String])] = [
                ([group[0], group[1]], [group[2], group[3]]),
                ([group[0], group[2]], [group[1], group[3]]),
                ([group[0], group[3]], [group[1], group[2]])
            ]
            for (a, b) in splits { fixtures.append(Fixture(teamA: a, teamB: b)) }
        }

        var gameCounts: [String: Int] = Dictionary(
            uniqueKeysWithValues: playerIDs.filter { $0 != "BYE" }.map { ($0, 0) }
        )
        var partnerCounts: [String: [String: Int]] = Dictionary(
            uniqueKeysWithValues: playerIDs.filter { $0 != "BYE" }.map { ($0, [:]) }
        )

        var scheduledGames: [Game] = []
        var roundNumber = 1
        let originalFixtures = fixtures

        while true {
            let allDone = gameCounts.values.allSatisfy { $0 >= targetGamesPerPlayer }
            if allDone { break }
            let minGames = gameCounts.values.min() ?? 0
            if minGames >= targetGamesPerPlayer { break }

            var bestIndex: Int? = nil
            var bestScore = Int.max

            for (i, fixture) in fixtures.enumerated() {
                if fixture.all4.contains(where: { (gameCounts[$0] ?? 0) >= targetGamesPerPlayer }) { continue }
                let totalGames = fixture.all4.reduce(0) { $0 + (gameCounts[$1] ?? 0) }
                var partnerRepeat = 0
                for pair in [fixture.teamA, fixture.teamB] {
                    partnerRepeat += (partnerCounts[pair[0]]?[pair[1]] ?? 0)
                }
                let score = totalGames * 10 + partnerRepeat
                if score < bestScore { bestScore = score; bestIndex = i }
            }

            guard let idx = bestIndex else { break }
            let chosen = fixtures[idx]

            scheduledGames.append(Game(
                matchID: match.id,
                round: roundNumber,
                playerAIDs: chosen.teamA,
                playerBIDs: chosen.teamB
            ))
            roundNumber += 1

            for p in chosen.all4 { gameCounts[p, default: 0] += 1 }
            for pair in [chosen.teamA, chosen.teamB] {
                let p1 = pair[0], p2 = pair[1]
                partnerCounts[p1, default: [:]][p2, default: 0] += 1
                partnerCounts[p2, default: [:]][p1, default: 0] += 1
            }

            fixtures.remove(at: idx)
            if fixtures.isEmpty { fixtures = originalFixtures }
        }

        if scheduledGames.isEmpty {
            errorMessage = "无法生成比赛，请检查球员数量和场数设置"
        }
        return scheduledGames
    }

    // MARK: - Combinatorics Helper

    private func combinations<T>(of array: [T], choosing k: Int) -> [[T]] {
        guard k > 0, k <= array.count else { return k == 0 ? [[]] : [] }
        if k == array.count { return [array] }
        var result: [[T]] = []
        func combine(start: Int, current: [T]) {
            if current.count == k { result.append(current); return }
            let remaining = k - current.count
            for i in start...(array.count - remaining) {
                combine(start: i + 1, current: current + [array[i]])
            }
        }
        combine(start: 0, current: [])
        return result
    }

    // MARK: - Score Saving

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

    // MARK: - Score Validation

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
            if score.playerAScore > score.playerBScore { aWins += 1 }
            else { bWins += 1 }
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

        if a == b { return "第 \(gameNumber) 局比分不能相同" }

        let winner = max(a, b)
        let loser = min(a, b)

        if rule.deuceEnabled {
            let cap = rule.deuceCapPoints ?? (target + 9)
            if loser < target - 1 {
                if winner != target { return "第 \(gameNumber) 局：非平分情况下，赢方应为 \(target) 分" }
            } else {
                if winner == cap {
                    if loser < cap - 2 { return "第 \(gameNumber) 局：封顶分 \(cap) 时，输方至少 \(cap - 2) 分" }
                } else if winner - loser != 2 {
                    return "第 \(gameNumber) 局：Deuce 后需领先2分才能获胜"
                }
            }
        } else {
            if winner != target { return "第 \(gameNumber) 局：赢方应为 \(target) 分" }
        }
        return nil
    }

    func isGameSetComplete(score: GameScore, rule: ScoringRule) -> Bool {
        validateSingleGame(score: score, rule: rule, gameNumber: 1) == nil && score.playerAScore != score.playerBScore
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

    // MARK: - Leaderboard

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
                if score.playerAScore > score.playerBScore { aGameWins += 1 }
                else { bGameWins += 1 }
            }

            let aWon = aGameWins >= winsNeeded

            for pid in game.playerAIDs {
                if aWon { entries[pid]?.wins += 1 } else { entries[pid]?.losses += 1 }
                entries[pid]?.gamesWon += aGameWins
                entries[pid]?.gamesLost += bGameWins
            }

            for pid in game.playerBIDs {
                if aWon { entries[pid]?.losses += 1 } else { entries[pid]?.wins += 1 }
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
