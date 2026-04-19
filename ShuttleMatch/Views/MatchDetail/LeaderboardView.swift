import SwiftUI

struct LeaderboardView: View {
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

#Preview {
    LeaderboardView(matchVM: MatchViewModel())
}
