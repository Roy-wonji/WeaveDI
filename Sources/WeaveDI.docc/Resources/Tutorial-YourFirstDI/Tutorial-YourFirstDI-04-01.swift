import SwiftUI
import DiContainer

struct ContentView: View {
    @Inject private var userService: UserService?

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, DiContainer!")

            if let userService {
                Text("✅ UserService 주입 성공!")
                    .foregroundColor(.green)
            } else {
                Text("❌ UserService 주입 실패")
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}