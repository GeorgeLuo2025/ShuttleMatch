import SwiftUI

struct ScoreInputView: View {
    let game: Game
    @ObservedObject var matchVM: MatchViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var scoreA: [Int]
    @State private var scoreB: [Int]
    @State private var currentGameCount: Int

    private var rule: ScoringRule {
        matchVM.currentMatch?.scoringRule ?? .standard
    }

    private var maxGames: Int {
        rule.gamesPerMatch
    }

    private var currentScores: [GameScore] {
        (0..<currentGameCount).map {
            GameScore(playerAScore: scoreA[$0], playerBScore: scoreB[$0])
        }
    }

    private var lastSetComplete: Bool {
        guard currentGameCount > 0 else { return false }
        let last = GameScore(
            playerAScore: scoreA[currentGameCount - 1],
            playerBScore: scoreB[currentGameCount - 1]
        )
        return matchVM.isGameSetComplete(score: last, rule: rule)
    }

    private var alreadyHasWinner: Bool {
        matchVM.hasMatchWinner(scores: currentScores, rule: rule)
    }

    private var canAddNextSet: Bool {
        currentGameCount < maxGames && lastSetComplete && !alreadyHasWinner
    }

    private var canDeleteLastSet: Bool {
        currentGameCount > 1
    }

    init(game: Game, matchVM: MatchViewModel) {
        self.game = game
        self.matchVM = matchVM

        if !game.scores.isEmpty {
            _scoreA = State(initialValue: game.scores.map { $0.playerAScore })
            _scoreB = State(initialValue: game.scores.map { $0.playerBScore })
            _currentGameCount = State(initialValue: game.scores.count)
        } else {
            _scoreA = State(initialValue: [0])
            _scoreB = State(initialValue: [0])
            _currentGameCount = State(initialValue: 1)
        }
    }

    private func playerName(id: String) -> String {
        matchVM.players.first(where: { $0.id == id })?.displayName ?? String(localized: "unknown_player")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(game.playerAIDs.map { playerName(id: $0) }.joined(separator: " & "))
                            .font(.headline)
                        Spacer()
                        Text("VS")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(game.playerBIDs.map { playerName(id: $0) }.joined(separator: " & "))
                            .font(.headline)
                    }
                }

                ForEach(0..<currentGameCount, id: \.self) { index in
                    Section("game_set_\(index + 1)") {
                        HStack {
                            TextField("A", value: $scoreA[index], format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)

                            Text(":")
                                .font(.title2)

                            TextField("B", value: $scoreB[index], format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                        }
                        .font(.title3)
                    }
                }

                Section {
                    if canAddNextSet {
                        Button {
                            scoreA.append(0)
                            scoreB.append(0)
                            currentGameCount += 1
                        } label: {
                            Label(String(localized: "add_next_game"), systemImage: "plus.circle")
                        }
                    }

                    if canDeleteLastSet {
                        Button(role: .destructive) {
                            currentGameCount -= 1
                            scoreA.removeLast()
                            scoreB.removeLast()
                        } label: {
                            Label(String(localized: "delete_last_game"), systemImage: "minus.circle")
                        }
                    }
                }

                if let error = matchVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task {
                            matchVM.errorMessage = nil
                            await matchVM.saveScoreDraft(game: game, scores: currentScores)
                            if matchVM.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        Text(String(localized: "save_draft"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            matchVM.errorMessage = nil
                            let success = await matchVM.confirmGameComplete(game: game, scores: currentScores)
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        Text(String(localized: "confirm_complete"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle(String(localized: "record_score_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel_button")) { dismiss() }
                }
            }
        }
    }
}
