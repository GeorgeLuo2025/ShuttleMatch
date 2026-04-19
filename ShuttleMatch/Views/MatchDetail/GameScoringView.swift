import SwiftUI

struct GameScoringView: View {
    @ObservedObject var matchVM: MatchViewModel

    var body: some View {
        Group {
            if matchVM.games.isEmpty {
                ContentUnavailableView(
                    String(localized: "no_games_title"),
                    systemImage: "sportscourt",
                    description: Text(String(localized: "generate_games_first"))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(matchVM.games) { game in
                            GameCardView(game: game, matchVM: matchVM)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct GameCardView: View {
    let game: Game
    @ObservedObject var matchVM: MatchViewModel
    @State private var isEditing = false

    private func playerName(id: String) -> String {
        matchVM.players.first(where: { $0.id == id })?.displayName ?? String(localized: "unknown_player")
    }

    private func sideLabel(_ ids: [String]) -> String {
        ids.map { playerName(id: $0) }.joined(separator: " & ")
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("round_\(game.round)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(game.status.localizedLabel)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(game.status.color.opacity(0.15))
                    .foregroundStyle(game.status.color)
                    .cornerRadius(4)
            }

            HStack {
                Text(sideLabel(game.playerAIDs))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text("VS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(sideLabel(game.playerBIDs))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if !game.scores.isEmpty {
                HStack(spacing: 16) {
                    ForEach(Array(game.scores.enumerated()), id: \.offset) { _, score in
                        Text("\(score.playerAScore):\(score.playerBScore)")
                            .font(.title3)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                }
            }

            if game.status == .completed {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(String(localized: "game_completed"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button(game.scores.isEmpty ? String(localized: "record_score") : String(localized: "edit_score")) {
                    isEditing = true
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .sheet(isPresented: $isEditing) {
            ScoreInputView(game: game, matchVM: matchVM)
        }
    }
}

extension GameStatus {
    var label: String { localizedLabel }
    var localizedLabel: String {
        switch self {
        case .pending: return String(localized: "game_status_pending")
        case .inProgress: return String(localized: "game_status_in_progress")
        case .completed: return String(localized: "game_status_completed")
        }
    }

    var color: Color {
        switch self {
        case .pending: return .gray
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

#Preview {
    GameScoringView(matchVM: MatchViewModel())
}
