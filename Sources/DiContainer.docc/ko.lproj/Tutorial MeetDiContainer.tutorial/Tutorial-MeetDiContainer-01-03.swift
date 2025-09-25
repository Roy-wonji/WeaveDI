import SwiftUI
import DiContainer

struct ContentView: View {
    @State private var count = 0

    // 🔥 DiContainer의 @Inject Property Wrapper 사용
    @Inject private var counterService: CounterService?

    var body: some View {
        VStack(spacing: 20) {
            Text("DiContainer 카운터")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("\(count)")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.blue)

            HStack(spacing: 20) {
                Button("-") {
                    if let service = counterService {
                        count = service.decrement(count)
                    }
                }
                .font(.title)
                .frame(width: 50, height: 50)
                .background(Color.red)
                .foregroundColor(.white)
                .clipShape(Circle())

                Button("+") {
                    if let service = counterService {
                        count = service.increment(count)
                    }
                }
                .font(.title)
                .frame(width: 50, height: 50)
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(Circle())

                Button("Reset") {
                    if let service = counterService {
                        count = service.reset()
                    }
                }
                .font(.title2)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            // 의존성 주입 상태 표시
            HStack {
                Image(systemName: counterService != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(counterService != nil ? .green : .red)
                Text("CounterService: \(counterService != nil ? "주입됨" : "없음")")
                    .font(.caption)
            }
            .padding(.top)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}