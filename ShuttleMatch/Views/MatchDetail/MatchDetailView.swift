import SwiftUI

#Preview {
    NavigationStack {
        MatchDetailView(matchID: "preview_id", isNewMatch: false)
    }
}

struct MatchDetailView: View {
    let matchID: String
    var isNewMatch: Bool = false

    @StateObject private var matchVM = MatchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showKeepAlert = false

    private var shouldConfirmOnBack: Bool {
        isNewMatch &&
        matchVM.currentMatch?.status == .registration &&
        matchVM.games.isEmpty
    }

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
            } else if matchVM.currentMatch != nil {
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
        .navigationTitle(matchVM.currentMatch?.name.isEmpty == false
            ? matchVM.currentMatch!.name
            : String(localized: "match_detail_title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(shouldConfirmOnBack)
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbar {
            if shouldConfirmOnBack {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showKeepAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(String(localized: "create_tab"))
                        }
                    }
                }
            }
        }
        .alert(String(localized: "keep_match_alert_title"), isPresented: $showKeepAlert) {
            Button(String(localized: "keep_match_yes")) {
                dismiss()
            }
            Button(String(localized: "keep_match_no"), role: .destructive) {
                Task {
                    await matchVM.deleteMatch()
                    dismiss()
                }
            }
        } message: {
            Text(String(localized: "keep_match_alert_message"))
        }
        .task {
            await matchVM.loadMatchDetail(matchID: matchID)
        }
    }
}
