import Foundation
import FirebaseAuth

class AuthService {
    static let shared = AuthService()

    var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    var isLoggedIn: Bool {
        currentUser != nil
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func register(email: String, password: String, displayName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()

        let player = Player(
            id: result.user.uid,
            email: email,
            displayName: displayName
        )
        try await FirestoreService.shared.savePlayer(player)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
