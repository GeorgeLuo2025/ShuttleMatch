import SwiftUI

struct MatchDetailView: View {
    let matchID: String
    @StateObject private var matchVM = MatchViewModel()
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text(String(localized: "registration_info_tab")).tag(0)
                Text(String(localized: "game_scoring_tab")).tag(1)
                Text(String(localized: "leaderboard_tab")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            if matchVM.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let match = matchVM.currentMatch {
                switch selectedTab {
                case 0:
                    RegistrationInfoView(matchVM: matchVM)
                case 1:
                    GameScoringView(matchVM: matchVM)
                case 2:
                    LeaderboardView(matchVM: matchVM)
                default:
                    EmptyView()
                }
            }
        }
        .navigationTitle(matchVM.currentMatch?.name ?? String(localized: "match_detail_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .tabBar)
        .task {
            await matchVM.loadMatchDetail(matchID: matchID)
        }
    }
}
