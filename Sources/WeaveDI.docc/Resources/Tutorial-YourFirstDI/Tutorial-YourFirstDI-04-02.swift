import SwiftUI
import WeaveDI

struct ContentView: View {
    @Inject private var userService: UserService?
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("사용자 데이터 로딩 중...")
                        .padding()
                } else if users.isEmpty {
                    VStack {
                        Image(systemName: "person.3")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("사용자 데이터를 불러오려면 아래 버튼을 눌러주세요")
                            .multilineTextAlignment(.center)
                            .padding()

                        Button("사용자 목록 가져오기") {
                            loadUsers()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(users) { user in
                        VStack(alignment: .leading) {
                            Text(user.name)
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(user.company.name)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 2)
                    }
                }

                if let errorMessage {
                    Text("⚠️ \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("WeaveDI 사용자")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("새로고침") {
                        loadUsers()
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            loadUsers()
        }
    }

    private func loadUsers() {
        guard let userService else {
            errorMessage = "UserService를 사용할 수 없습니다"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let fetchedUsers = try await userService.getUsers()
                await MainActor.run {
                    users = fetchedUsers
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}