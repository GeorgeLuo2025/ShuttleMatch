import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel

    private var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentUser?.displayName ?? String(localized: "no_nickname"))
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(String(localized: "settings_section")) {
                    NavigationLink(String(localized: "edit_profile")) {
                        Text(String(localized: "edit_profile"))
                    }
                    NavigationLink(String(localized: "match_history")) {
                        Text(String(localized: "match_history"))
                    }
                }

                Section {
                    Button(String(localized: "logout_button"), role: .destructive) {
                        authVM.signOut()
                    }
                }
            }
            .navigationTitle(String(localized: "my_profile_title"))
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
