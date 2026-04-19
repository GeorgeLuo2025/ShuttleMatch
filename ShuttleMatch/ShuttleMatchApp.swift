import SwiftUI
import FirebaseCore

@main
struct ShuttleMatchApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthViewModel())
        }
    }
}
