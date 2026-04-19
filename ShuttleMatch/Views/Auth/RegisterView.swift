import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "account_info_section")) {
                    TextField(String(localized: "display_name_placeholder"), text: $displayName)
                    TextField(String(localized: "email_placeholder"), text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField(String(localized: "password_placeholder"), text: $password)
                    SecureField(String(localized: "confirm_password_placeholder"), text: $confirmPassword)

                    if passwordMismatch {
                        Text(String(localized: "password_mismatch"))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let error = authVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await authVM.register(email: email, password: password, displayName: displayName)
                            if authVM.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if authVM.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(String(localized: "register_button"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        displayName.isEmpty ||
                        email.isEmpty ||
                        password.isEmpty ||
                        passwordMismatch ||
                        authVM.isLoading
                    )
                }
            }
            .navigationTitle(String(localized: "register_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel_button")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthViewModel())
}
