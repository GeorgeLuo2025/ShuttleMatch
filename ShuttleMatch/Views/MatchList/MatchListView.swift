import SwiftUI
import FirebaseAuth

struct MatchListView: View {
    @StateObject private var matchVM = MatchViewModel()
    @State private var selectedTab = 0
    @State private var matchToDelete: Match? = nil

    private var currentUserID: String? { Auth.auth().currentUser?.uid }

    private var organizedMatches: [Match] {
        matchVM.matches.filter { $0.organizerID == currentUserID }
    }

    private var joinedMatches: [Match] {
        matchVM.matches.filter {
            $0.playerIDs.contains(currentUserID ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text(String(localized: "tab_my_organized")).tag(0)
                    Text(String(localized: "tab_my_joined")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if matchVM.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    let displayList = selectedTab == 0 ? organizedMatches : joinedMatches

                    if displayList.isEmpty {
                        ContentUnavailableView(
                            String(localized: "no_matches_title"),
                            systemImage: "figure.badminton",
                            description: Text(selectedTab == 0
                                ? String(localized: "no_organized_matches_description")
                                : String(localized: "no_joined_matches_description"))
                        )
                    } else {
                        List(displayList) { match in
                            NavigationLink(value: match) {
                                MatchRowView(match: match)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if selectedTab == 0 {
                                    Button(role: .destructive) {
                                        matchToDelete = match
                                    } label: {
                                        Label(String(localized: "delete_button"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .navigationDestination(for: Match.self) { match in
                            MatchDetailView(matchID: match.id)
                        }
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
            .alert(String(localized: "delete_match_alert_title"), isPresented: Binding(
                get: { matchToDelete != nil },
                set: { if !$0 { matchToDelete = nil } }
            )) {
                Button(String(localized: "delete_button"), role: .destructive) {
                    if let match = matchToDelete {
                        Task { await matchVM.deleteMatchByID(match.id) }
                    }
                    matchToDelete = nil
                }
                Button(String(localized: "cancel_button"), role: .cancel) {
                    matchToDelete = nil
                }
            } message: {
                Text(String(localized: "delete_match_alert_message"))
            }
        }
    }
}

struct MatchRowView: View {
    let match: Match

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(match.name.isEmpty ? String(localized: "unnamed_match") : match.name)
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
