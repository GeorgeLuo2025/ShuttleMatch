import SwiftUI
import FirebaseAuth

struct EditProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var gender: Gender? = nil
    @State private var birthYear: Int? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDiscardAlert = false

    @State private var initialDisplayName = ""
    @State private var initialGender: Gender? = nil
    @State private var initialBirthYear: Int? = nil

    private let years: [Int] = Array((1940...2015).reversed())

    private var hasChanges: Bool {
        displayName != initialDisplayName ||
        gender != initialGender ||
        birthYear != initialBirthYear
    }

    var body: some View {
        Form {
            Section(String(localized: "edit_profile_basic_section")) {
                TextField(String(localized: "display_name_placeholder"), text: $displayName)
            }

            Section(String(localized: "edit_profile_gender_section")) {
                Picker(String(localized: "gender_label"), selection: $gender) {
                    Text(String(localized: "gender_not_set")).tag(Optional<Gender>.none)
                    ForEach(Gender.allCases, id: \.self) { g in
                        Text(g.label).tag(Optional(g))
                    }
                }
            }

            Section(String(localized: "edit_profile_birth_year_section")) {
                Picker(String(localized: "birth_year_label"), selection: $birthYear) {
                    Text(String(localized: "birth_year_not_set")).tag(Optional<Int>.none)
                    ForEach(years, id: \.self) { year in
                        Text(String(year)).tag(Optional(year))
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(String(localized: "edit_profile"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    if hasChanges {
                        showDiscardAlert = true
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(String(localized: "my_profile_title"))
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "save_button")) {
                    Task { await save() }
                }
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
        }
        .alert(String(localized: "discard_changes_title"), isPresented: $showDiscardAlert) {
            Button(String(localized: "discard_button"), role: .destructive) { dismiss() }
            Button(String(localized: "keep_editing_button"), role: .cancel) {}
        } message: {
            Text(String(localized: "discard_changes_message"))
        }
        .onAppear { loadCurrentProfile() }
    }

    private func loadCurrentProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Task {
            if let player = try? await FirestoreService.shared.getPlayer(id: uid) {
                displayName = player.displayName
                gender = player.gender
                birthYear = player.birthYear
            } else {
                displayName = Auth.auth().currentUser?.displayName ?? ""
            }
            initialDisplayName = displayName
            initialGender = gender
            initialBirthYear = birthYear
        }
    }

    private func save() async {
        isLoading = true
        errorMessage = nil
        guard let uid = Auth.auth().currentUser?.uid,
              let email = Auth.auth().currentUser?.email else { return }

        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        changeRequest?.displayName = displayName
        do {
            try await changeRequest?.commitChanges()

            var player = Player(id: uid, email: email, displayName: displayName)
            player.gender = gender
            player.birthYear = birthYear
            try await FirestoreService.shared.savePlayer(player)

            await MainActor.run {
                authVM.currentUserDisplayName = displayName
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthViewModel())
    }
}
