import SwiftUI

struct MatchListView: View {
    @StateObject private var matchVM = MatchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if matchVM.isLoading {
                    ProgressView()
                } else if matchVM.matches.isEmpty {
                    ContentUnavailableView(
                        String(localized: "no_matches_title"),
                        systemImage: "figure.badminton",
                        description: Text(String(localized: "no_matches_description"))
                    )
                } else {
                    List(matchVM.matches) { match in
                        NavigationLink(value: match) {
                            MatchRowView(match: match)
                        }
                    }
                    .navigationDestination(for: Match.self) { match in
                        MatchDetailView(matchID: match.id)
                    }
                }
            }
            .navigationTitle(String(localized: "matches_list_title"))
            .task {
                await matchVM.loadMatches()
            }
            .refreshable {
                await matchVM.loadMatches()
            }
        }
    }
}

struct MatchRowView: View {
    let match: Match

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(match.name)
                    .font(.headline)
                Spacer()
                Text(match.status.localizedLabel)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(match.status.color.opacity(0.15))
                    .foregroundStyle(match.status.color)
                    .cornerRadius(4)
            }

            HStack {
                Text(match.type.localizedLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("player_count_\(match.playerIDs.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

extension Match: Hashable {
    static func == (lhs: Match, rhs: Match) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension MatchStatus {
    var color: Color {
        switch self {
        case .registration: return .blue
        case .ongoing: return .orange
        case .finished: return .green
        }
    }
}

#Preview {
    MatchListView()
}
