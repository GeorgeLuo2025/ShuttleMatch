import Foundation
import Combine
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUserDisplayName: String = ""

    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isLoggedIn = user != nil
                self?.currentUserDisplayName = user?.displayName ?? ""
            }
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await AuthService.shared.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func register(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await AuthService.shared.register(email: email, password: password, displayName: displayName)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        do {
            try AuthService.shared.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
