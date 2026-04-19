import SwiftUI
import FirebaseAuth

struct RegistrationInfoView: View {
    @ObservedObject var matchVM: MatchViewModel
    @State private var isShowingAddPlayer = false

    @State private var matchName = ""
    @State private var useStandardScoring = true
    @State private var customPointsPerGame = 21
    @State private var customGamesPerMatch = 3
    @State private var deuceEnabled = true
    @State private var selectedRounds = 0
    @State private var hasInitialized = false

    @State private var singlesCount = 2
    @State private var doublesCount = 2
    @State private var teamAName = ""
    @State private var teamBName = ""

    private var match: Match? { matchVM.currentMatch }
    private var isOrganizer: Bool {
        match?.organizerID == Auth.auth().currentUser?.uid
    }
    private var isRegistration: Bool {
        match?.status == .registration
    }
    private var playerCount: Int {
        matchVM.players.count
    }

    private var recommendedRounds: [Int] {
        guard playerCount >= 2 else { return [] }
        let n = playerCount
        if n % 2 == 0 {
            return Array(1...min(n - 1, 15))
        } else {
            var options: [Int] = []
            options.append(n)
            if n - 1 >= 1 { options.append(n - 1) }
            if 2 * n <= 20 { options.append(2 * n) }
            return options.sorted()
        }
    }

    var body: some View {
        List {
            if let match {
                if isRegistration && isOrganizer {
                    Section(String(localized: "match_settings_section")) {
                        TextField(String(localized: "match_name_placeholder"), text: $matchName)
                            .onChange(of: matchName) { _, _ in saveSettings() }
                    }

                    if match.type == .team {
                        Section(String(localized: "teams_section")) {
                            TextField(String(localized: "team_a_name"), text: $teamAName)
                            TextField(String(localized: "team_b_name"), text: $teamBName)
                        }
                        Section(String(localized: "game_settings_section")) {
                            Stepper("singles_count_\(singlesCount)", value: $singlesCount, in: 0...5)
                            Stepper("doubles_count_\(doublesCount)", value: $doublesCount, in: 0...5)
                        }
                    }

                    Section(String(localized: "scoring_rule_section")) {
                        Toggle(String(localized: "standard_rules_toggle"), isOn: $useStandardScoring)
                            .onChange(of: useStandardScoring) { _, _ in saveSettings() }

                        if !useStandardScoring {
                            Stepper("points_per_game_\(customPointsPerGame)", value: $customPointsPerGame, in: 5...50)
                            Stepper("games_per_match_\(customGamesPerMatch)", value: $customGamesPerMatch, in: 1...7, step: 2)
                            Toggle(String(localized: "enable_deuce"), isOn: $deuceEnabled)
                        }
                    }
                } else {
                    Section(String(localized: "match_info_section")) {
                        LabeledContent(String(localized: "match_type_label"), value: match.type.localizedLabel)
                        LabeledContent(String(localized: "status_label"), value: match.status.localizedLabel)
                        LabeledContent(String(localized: "rounds_label"), value: "\(match.rounds)")
                        LabeledContent(String(localized: "scoring_label"), value: match.scoringRule.localizedLabel)
                    }
                }

                Section("registration_list_\(playerCount)") {
                    if matchVM.players.isEmpty {
                        Text(String(localized: "no_registration_add_players"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(matchVM.players) { player in
                            HStack {
                                Text(player.displayName)
                                Spacer()
                                if player.id == match.organizerID {
                                    Text(String(localized: "organizer_badge"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            guard isRegistration && isOrganizer else { return }
                            Task {
                                for index in indexSet {
                                    await matchVM.removePlayer(playerID: matchVM.players[index].id)
                                }
                            }
                        }
                    }

                    if isOrganizer && isRegistration {
                        Button {
                            isShowingAddPlayer = true
                        } label: {
                            Label(String(localized: "add_player_button"), systemImage: "person.badge.plus")
                        }
                    }
                }

                if isOrganizer && isRegistration && playerCount >= 2 && match.type != .team {
                    Section(String(localized: "rounds_settings_section")) {
                        if recommendedRounds.isEmpty {
                            Text(String(localized: "please_add_players_first"))
                                .foregroundStyle(.secondary)
                        } else {
                            Picker(String(localized: "match_rounds_picker"), selection: $selectedRounds) {
                                ForEach(recommendedRounds, id: \.self) { r in
                                    Text(roundLabel(r)).tag(r)
                                }
                            }
                            .pickerStyle(.menu)

                            Text(roundExplanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if isOrganizer && isRegistration && canGenerate {
                    Section {
                        Button {
                            Task { await generateMatchups() }
                        } label: {
                            Text(String(localized: "generate_matchups_button"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddPlayer) {
            AddPlayerView(matchVM: matchVM)
        }
        .onAppear { initializeFromMatch() }
        .onChange(of: matchVM.currentMatch?.id) { _, _ in initializeFromMatch() }
    }

    private var canGenerate: Bool {
        guard playerCount >= 2 else { return false }
        guard !matchName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if match?.type == .team {
            return !teamAName.isEmpty && !teamBName.isEmpty
        }
        return selectedRounds > 0
    }

    private func roundLabel(_ r: Int) -> String {
        let n = playerCount
        if n % 2 == 0 {
            return "\(r) rounds (\(r) games per player)"
        } else {
            let byePerPlayer = r / n
            let gamesPerPlayer = r - byePerPlayer
            return "\(r) rounds (~\(gamesPerPlayer) games per player)"
        }
    }

    private var roundExplanation: String {
        let n = playerCount
        if n % 2 == 0 {
            return "\(n) players (even), all play every round"
        } else {
            return "\(n) players (odd), 1 bye per round, recommended rounds ensure equal byes"
        }
    }

    private func initializeFromMatch() {
        guard !hasInitialized, let match else { return }
        matchName = match.name
        useStandardScoring = (match.scoringRule == .standard)
        customPointsPerGame = match.scoringRule.pointsPerGame
        customGamesPerMatch = match.scoringRule.gamesPerMatch
        deuceEnabled = match.scoringRule.deuceEnabled
        selectedRounds = match.rounds

        if let teamA = match.teamA { teamAName = teamA.name }
        if let teamB = match.teamB { teamBName = teamB.name }

        if selectedRounds == 0 && !recommendedRounds.isEmpty {
            selectedRounds = recommendedRounds.first ?? 0
        }
        hasInitialized = true
    }

    private func saveSettings() {}

    private func generateMatchups() async {
        let rule: ScoringRule = useStandardScoring ? .standard : ScoringRule(
            pointsPerGame: customPointsPerGame,
            gamesPerMatch: customGamesPerMatch,
            deuceEnabled: deuceEnabled,
            deuceCapPoints: deuceEnabled ? customPointsPerGame + 9 : nil
        )

        matchVM.currentMatch?.name = matchName
        matchVM.currentMatch?.scoringRule = rule
        matchVM.currentMatch?.rounds = selectedRounds

        if matchVM.currentMatch?.type == .team {
            matchVM.currentMatch?.teamA?.name = teamAName
            matchVM.currentMatch?.teamB?.name = teamBName
            matchVM.currentMatch?.rounds = singlesCount + doublesCount

            var slots: [TeamMatchSlot] = []
            for i in 0..<singlesCount {
                slots.append(TeamMatchSlot(slotType: .singles, slotOrder: i + 1))
            }
            for i in 0..<doublesCount {
                slots.append(TeamMatchSlot(slotType: .doubles, slotOrder: i + 1))
            }
            matchVM.currentMatch?.teamMatchSlots = slots
        }

        if let match = matchVM.currentMatch {
            try? await FirestoreService.shared.updateMatch(match)
        }

        await matchVM.generateMatchups()
    }
}

struct AddPlayerView: View {
    @ObservedObject var matchVM: MatchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack {
                TextField(String(localized: "search_user_placeholder"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: searchText) { _, newValue in
                        Task { await matchVM.searchUsers(query: newValue) }
                    }

                List(matchVM.searchResults) { player in
                    let alreadyAdded = matchVM.currentMatch?.playerIDs.contains(player.id) ?? false
                    HStack {
                        VStack(alignment: .leading) {
                            Text(player.displayName)
                            Text(player.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if alreadyAdded {
                            Text(String(localized: "already_added"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(String(localized: "add_button")) {
                                Task { await matchVM.addPlayer(playerID: player.id) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "add_player_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done_button")) { dismiss() }
                }
            }
        }
    }
}

extension MatchStatus {
    var label: String { localizedLabel }
    var localizedLabel: String {
        switch self {
        case .registration: return String(localized: "status_registration")
        case .ongoing: return String(localized: "status_ongoing")
        case .finished: return String(localized: "status_finished")
        }
    }
}

extension ScoringRule {
    var label: String { localizedLabel }
    var localizedLabel: String {
        if self == .standard {
            return String(localized: "scoring_standard")
        }
        return "\(pointsPerGame)pts / Best of \(gamesPerMatch)"
    }
}
