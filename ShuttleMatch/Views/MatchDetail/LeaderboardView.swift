import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var matchVM: MatchViewModel

    var body: some View {
        Group {
            if let match = matchVM.currentMatch, match.type == .team {
                TeamLeaderboardView(matchVM: matchVM)
            } else {
                IndividualLeaderboardView(matchVM: matchVM)
            }
        }
    }
}

// MARK: - Individual Leaderboard (Singles / Doubles League)

struct IndividualLeaderboardView: View {
    @ObservedObject var matchVM: MatchViewModel

    var body: some View {
        Group {
            if matchVM.leaderboard.isEmpty {
                ContentUnavailableView(
                    String(localized: "no_leaderboard_title"),
                    systemImage: "trophy",
                    description: Text(String(localized: "leaderboard_auto_generated"))
                )
            } else {
                List {
                    ForEach(Array(matchVM.leaderboard.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .frame(width: 30)
                                .foregroundStyle(index < 3 ? .orange : .primary)

                            Text(entry.playerName)
                                .font(.body)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(entry.wins)W \(entry.losses)L")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                let sign = entry.netGames > 0 ? "+" : ""
                                Text("net_games_\(sign)\(entry.netGames)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Team Leaderboard

struct TeamLeaderboardView: View {
    @ObservedObject var matchVM: MatchViewModel

    private var match: Match? { matchVM.currentMatch }

    /// Aggregate team-level wins from completed games
    private var teamScore: (teamAWins: Int, teamBWins: Int) {
        var aWins = 0
        var bWins = 0
        guard let match else { return (0, 0) }
        let rule = match.scoringRule
        let winsNeeded = rule.gamesPerMatch / 2 + 1

        for game in matchVM.games where game.status == .completed {
            var aGameWins = 0
            var bGameWins = 0
            for score in game.scores {
                if score.playerAScore > score.playerBScore { aGameWins += 1 }
                else { bGameWins += 1 }
            }
            if aGameWins >= winsNeeded { aWins += 1 }
            else if bGameWins >= winsNeeded { bWins += 1 }
        }
        return (aWins, bWins)
    }

    /// Total games (sets) scored across all completed matches per team
    private var totalSets: (teamA: Int, teamB: Int) {
        var a = 0, b = 0
        guard let match else { return (0, 0) }
        let rule = match.scoringRule
        let winsNeeded = rule.gamesPerMatch / 2 + 1
        for game in matchVM.games where game.status == .completed {
            var aGameWins = 0, bGameWins = 0
            for score in game.scores {
                if score.playerAScore > score.playerBScore { aGameWins += 1 }
                else { bGameWins += 1 }
            }
            // Attribute sets to the team that won the game
            if aGameWins >= winsNeeded {
                a += aGameWins; b += bGameWins
            } else {
                b += bGameWins; a += aGameWins
            }
        }
        return (a, b)
    }

    private var teamAPlayers: [LeaderboardEntry] {
        let ids = Set(match?.teamA?.memberIDs ?? [])
        return matchVM.leaderboard.filter { ids.contains($0.playerID) }
    }

    private var teamBPlayers: [LeaderboardEntry] {
        let ids = Set(match?.teamB?.memberIDs ?? [])
        return matchVM.leaderboard.filter { ids.contains($0.playerID) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Team score header
                teamScoreHeader

                // Side-by-side player rankings
                playerComparisonSection
            }
            .padding()
        }
    }

    private var teamScoreHeader: some View {
        let score = teamScore
        let sets = totalSets
        let aWon = score.teamAWins > score.teamBWins
        let bWon = score.teamBWins > score.teamAWins

        return VStack(spacing: 8) {
            HStack {
                // Team A
                VStack(spacing: 2) {
                    Text(match?.teamA?.name ?? "Team A")
                        .font(.headline)
                        .fontWeight(.bold)
                    if aWon {
                        Text("Win").font(.caption).foregroundStyle(.green).fontWeight(.medium)
                    } else if bWon {
                        Text("Lost").font(.caption).foregroundStyle(.red)
                    } else {
                        Text("Draw").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Text("VS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)

                // Team B
                VStack(spacing: 2) {
                    Text(match?.teamB?.name ?? "Team B")
                        .font(.headline)
                        .fontWeight(.bold)
                    if bWon {
                        Text("Win").font(.caption).foregroundStyle(.green).fontWeight(.medium)
                    } else if aWon {
                        Text("Lost").font(.caption).foregroundStyle(.red)
                    } else {
                        Text("Draw").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Big score
            HStack(alignment: .center, spacing: 0) {
                Text("\(score.teamAWins)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(aWon ? .primary : .secondary)
                    .frame(maxWidth: .infinity)

                Text(":")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)

                Text("\(score.teamBWins)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(bWon ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
            }

            // Sets sub-score
            HStack {
                Text("\(sets.teamA)")
                    .frame(maxWidth: .infinity)
                Text("scores")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
                Text("\(sets.teamB)")
                    .frame(maxWidth: .infinity)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var playerComparisonSection: some View {
        let maxCount = max(teamAPlayers.count, teamBPlayers.count)

        return VStack(spacing: 0) {
            // Column headers
            HStack {
                Text(match?.teamA?.name ?? "Team A")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Text(match?.teamB?.name ?? "Team B")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 8)

            ForEach(0..<maxCount, id: \.self) { i in
                HStack(spacing: 8) {
                    // Team A player
                    if i < teamAPlayers.count {
                        playerCell(entry: teamAPlayers[i])
                    } else {
                        Color.clear.frame(maxWidth: .infinity, minHeight: 60)
                    }

                    // Team B player
                    if i < teamBPlayers.count {
                        playerCell(entry: teamBPlayers[i])
                    } else {
                        Color.clear.frame(maxWidth: .infinity, minHeight: 60)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func playerCell(entry: LeaderboardEntry) -> some View {
        VStack(spacing: 2) {
            Text(entry.playerName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            Text("\(entry.wins)W - \(entry.losses)L")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    LeaderboardView(matchVM: MatchViewModel())
}
