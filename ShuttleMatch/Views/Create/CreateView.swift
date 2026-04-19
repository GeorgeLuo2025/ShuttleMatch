import SwiftUI
import FirebaseAuth

struct CreateView: View {
    @StateObject private var matchVM = MatchViewModel()
    @State private var navigateToMatch: Match?
    @State private var isNavigating = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(String(localized: "select_match_type"))
                    .font(.headline)
                    .padding(.top)

                ForEach(MatchType.allCases, id: \.self) { type in
                    Button {
                        Task { await createAndNavigate(type: type) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.localizedLabel)
                                    .font(.headline)
                                Text(type.localizedDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal)
            .navigationTitle(String(localized: "create_match_title"))
            .navigationDestination(isPresented: $isNavigating) {
                if let match = navigateToMatch {
                    MatchDetailView(matchID: match.id)
                }
            }
        }
    }

    private func createAndNavigate(type: MatchType) async {
        let match = await matchVM.createMatch(
            name: "",
            type: type,
            rounds: 0,
            scoringRule: .standard
        )
        if let match {
            navigateToMatch = match
            isNavigating = true
        }
    }
}

extension MatchType {
    var localizedLabel: String {
        switch self {
        case .individualSingles: return String(localized: "individual_singles_label")
        case .individualDoubles: return String(localized: "individual_doubles_label")
        case .team: return String(localized: "team_match_label")
        }
    }

    var localizedDescription: String {
        switch self {
        case .individualSingles: return String(localized: "singles_description")
        case .individualDoubles: return String(localized: "doubles_description")
        case .team: return String(localized: "team_description")
        }
    }
}
