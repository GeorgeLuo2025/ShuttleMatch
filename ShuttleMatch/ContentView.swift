import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        if authVM.isLoggedIn {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab(String(localized: "create_tab"), systemImage: "plus.circle") {
                CreateView()
            }
            Tab(String(localized: "list_tab"), systemImage: "list.bullet") {
                MatchListView()
            }
            Tab(String(localized: "my_tab"), systemImage: "person.circle") {
                ProfileView()
            }
        }
    }
}
