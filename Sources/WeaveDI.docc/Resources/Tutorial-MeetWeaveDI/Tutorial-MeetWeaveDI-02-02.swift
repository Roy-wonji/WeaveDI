import SwiftUI
import WeaveDI

struct ContentView: View {
    @State private var count = 0

    // 🔥 @Inject: 싱글톤 - 같은 인스턴스 재사용
    @Inject private var counterService: CounterService?

    // 🚀 @Factory: 매번 새로운 인스턴스 생성
    @Factory private var logger: LoggingService?

    var body: some View {
        VStack(spacing: 20) {
            Text("WeaveDI 카운터")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("\(count)")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.blue)

            HStack(spacing: 20) {
                Button("-") {
                    if let service = counterService {
                        count = service.decrement(count)
                        logger?.logAction("감소 버튼 클릭")
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
                        logger?.logAction("증가 버튼 클릭")
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
                        logger?.logAction("리셋 버튼 클릭")
                    }
                }
                .font(.title2)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: counterService != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(counterService != nil ? .green : .red)
                    Text("CounterService: \(counterService != nil ? "주입됨 (싱글톤)" : "없음")")
                        .font(.caption)
                }

                HStack {
                    Image(systemName: logger != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(logger != nil ? .green : .red)
                    Text("Logger: \(logger?.sessionId ?? "없음") (Factory)")
                        .font(.caption)
                }

                Text("💡 각 버튼을 누를 때마다 새로운 Logger 세션이 생성됩니다!")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)
        }
        .padding()
        .onAppear {
            logger?.logInfo("앱 시작됨")
        }
    }
}

#Preview {
    ContentView()
}