import SwiftUI
import WeaveDI

struct ContentView: View {
    @State private var count = 0
    @State private var networkStatus = "확인 중..."
    @State private var isCheckingNetwork = false

    // 🔥 @Inject: 싱글톤 - 같은 인스턴스 재사용
    @Inject private var counterService: CounterService?

    // 🚀 @Factory: 매번 새로운 인스턴스 생성
    @Factory private var logger: LoggingService?

    // 🛡️ @SafeInject: 안전한 의존성 주입 (에러 처리)
    @SafeInject private var networkService: NetworkService?

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

            // 🌐 네트워크 상태 섹션
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                    Text("네트워크 상태: \(networkStatus)")
                        .font(.headline)
                }

                Button(isCheckingNetwork ? "확인 중..." : "네트워크 확인") {
                    checkNetworkStatus()
                }
                .disabled(isCheckingNetwork)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(isCheckingNetwork ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            // 의존성 상태 표시
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

                HStack {
                    // SafeInject 상태 표시
                    let networkResult = networkService
                    let isNetworkAvailable = networkResult?.success != nil

                    Image(systemName: isNetworkAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isNetworkAvailable ? .green : .red)
                    Text("NetworkService: \(isNetworkAvailable ? "주입됨 (SafeInject)" : "안전하게 처리됨")")
                        .font(.caption)
                }
            }
            .padding(.top)
        }
        .padding()
        .onAppear {
            logger?.logInfo("앱 시작됨")
            checkNetworkStatus()
        }
    }

    private func checkNetworkStatus() {
        isCheckingNetwork = true
        networkStatus = "확인 중..."

        Task {
            // SafeInject 사용법: 안전하게 에러 처리
            switch networkService {
            case .success(let service):
                let connected = await service.checkConnection()
                await MainActor.run {
                    networkStatus = connected ? "연결됨 ✅" : "연결 실패 ❌"
                    isCheckingNetwork = false
                }

            case .failure(let error):
                await MainActor.run {
                    networkStatus = "서비스 없음: \(error.localizedDescription)"
                    isCheckingNetwork = false
                }

            case .none:
                await MainActor.run {
                    networkStatus = "NetworkService 등록되지 않음"
                    isCheckingNetwork = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}