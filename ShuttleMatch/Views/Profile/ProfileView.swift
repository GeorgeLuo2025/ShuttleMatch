import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var matchVM = MatchViewModel()

    private var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    private var currentUserID: String? { Auth.auth().currentUser?.uid }

    private var totalMatches: Int { matchVM.matches.count }

    private var organizedCount: Int {
        matchVM.matches.filter { $0.organizerID == currentUserID }.count
    }

    private var ongoingCount: Int {
        matchVM.matches.filter { $0.status == .ongoing }.count
    }

    private var finishedCount: Int {
        matchVM.matches.filter { $0.status == .finished }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentUser?.displayName ?? String(localized: "no_nickname"))
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(currentUser?.email ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section(String(localized: "dashboard_section")) {
                    if matchVM.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(value: totalMatches, label: String(localized: "stat_total_matches"), color: .blue)
                            StatCard(value: organizedCount, label: String(localized: "stat_organized"), color: .purple)
                            StatCard(value: ongoingCount, label: String(localized: "stat_ongoing"), color: .orange)
                            StatCard(value: finishedCount, label: String(localized: "stat_finished"), color: .green)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(String(localized: "settings_section")) {
                    NavigationLink(String(localized: "edit_profile")) {
                        EditProfileView()
                            .environmentObject(authVM)
                    }
                }

                Section {
                    Button(String(localized: "logout_button"), role: .destructive) {
                        authVM.signOut()
                    }
                }
            }
            .navigationTitle(String(localized: "my_profile_title"))
            .task {
                await matchVM.loadMatches()
            }
            .refreshable {
                await matchVM.loadMatches()
            }
        }
    }
}

struct StatCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
