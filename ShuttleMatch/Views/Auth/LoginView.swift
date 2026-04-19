import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text(String(localized: "app_name"))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(String(localized: "login_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 16) {
                    TextField(String(localized: "email_placeholder"), text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField(String(localized: "password_placeholder"), text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task {
                            await authVM.signIn(email: email, password: password)
                        }
                    } label: {
                        if authVM.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(String(localized: "login_button"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || authVM.isLoading)
                }
                .padding(.horizontal)

                Button(String(localized: "no_account_register")) {
                    isShowingRegister = true
                }
                .font(.footnote)

                Spacer()
            }
            .sheet(isPresented: $isShowingRegister) {
                RegisterView()
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
