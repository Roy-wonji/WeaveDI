import SwiftUI
import WeaveDI

struct ContentView: View {
    @State private var count = 0
    @State private var history: [CounterHistory] = []
    @State private var networkStatus = "확인 중..."
    @State private var isLoading = false

    // 🎯 Clean Architecture: UseCase를 통한 비즈니스 로직 접근
    @Inject private var counterUseCase: CounterUseCase?

    // 🚀 Factory Pattern: 매번 새로운 로거
    @Factory private var logger: LoggingService?

    // 🛡️ SafeInject: 안전한 네트워크 서비스 처리
    @SafeInject private var networkService: NetworkService?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 카운터 표시
                VStack {
                    Text("WeaveDI 카운터")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("\(count)")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.blue)
                }

                // 카운터 버튼들
                HStack(spacing: 20) {
                    Button("-") {
                        decrementCounter()
                    }
                    .font(.title)
                    .frame(width: 50, height: 50)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .disabled(isLoading)

                    Button("+") {
                        incrementCounter()
                    }
                    .font(.title)
                    .frame(width: 50, height: 50)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .disabled(isLoading)

                    Button("Reset") {
                        resetCounter()
                    }
                    .font(.title2)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(isLoading)
                }

                Divider()

                // 네트워크 상태
                networkStatusSection

                Divider()

                // 히스토리 섹션
                historySection

                // Property Wrapper 상태 표시
                dependencyStatusSection
            }
            .padding()
            .navigationTitle("Clean Architecture")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadInitialData()
            }
        }
    }

    // MARK: - View Components

    private var networkStatusSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.blue)
                Text("네트워크: \(networkStatus)")
                    .font(.subheadline)
            }

            Button("연결 확인") {
                checkNetworkStatus()
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(6)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock")
                Text("히스토리 (\(history.count))")
                    .font(.headline)
                Spacer()
                Button("새로고침") {
                    refreshHistory()
                }
                .font(.caption)
            }

            if history.isEmpty {
                Text("히스토리가 없습니다")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(history.suffix(5), id: \.timestamp) { entry in
                            HStack {
                                Text("[\(entry.formattedTime)]")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(entry.action): \(entry.count)")
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var dependencyStatusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Property Wrapper 상태")
                .font(.headline)

            dependencyStatus(
                icon: counterUseCase != nil ? "checkmark.circle.fill" : "xmark.circle.fill",
                color: counterUseCase != nil ? .green : .red,
                text: "CounterUseCase: \(counterUseCase != nil ? "주입됨 (@Inject)" : "없음")"
            )

            dependencyStatus(
                icon: logger != nil ? "checkmark.circle.fill" : "xmark.circle.fill",
                color: logger != nil ? .green : .red,
                text: "Logger: \(logger?.sessionId ?? "없음") (@Factory)"
            )

            let networkResult = networkService
            let isNetworkAvailable = networkResult?.success != nil
            dependencyStatus(
                icon: isNetworkAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                color: isNetworkAvailable ? .green : .orange,
                text: "NetworkService: \(isNetworkAvailable ? "주입됨" : "안전하게 처리됨") (@SafeInject)"
            )
        }
        .font(.caption)
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
    }

    private func dependencyStatus(icon: String, color: Color, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
            Spacer()
        }
    }

    // MARK: - Actions

    private func loadInitialData() async {
        isLoading = true
        logger?.logInfo("앱 초기 데이터 로딩 시작")

        if let useCase = counterUseCase {
            count = await useCase.loadInitialCount()
            await refreshHistoryData()
        }

        await checkNetworkStatus()
        isLoading = false
    }

    private func incrementCounter() {
        guard let useCase = counterUseCase else { return }

        isLoading = true
        Task {
            count = await useCase.incrementCounter(current: count)
            await refreshHistoryData()
            isLoading = false
        }
    }

    private func decrementCounter() {
        guard let useCase = counterUseCase else { return }

        isLoading = true
        Task {
            count = await useCase.decrementCounter(current: count)
            await refreshHistoryData()
            isLoading = false
        }
    }

    private func resetCounter() {
        guard let useCase = counterUseCase else { return }

        isLoading = true
        Task {
            count = await useCase.resetCounter()
            await refreshHistoryData()
            isLoading = false
        }
    }

    private func refreshHistory() {
        Task {
            await refreshHistoryData()
        }
    }

    private func refreshHistoryData() async {
        guard let useCase = counterUseCase else { return }
        let newHistory = await useCase.getCounterHistory()
        await MainActor.run {
            history = newHistory
        }
    }

    private func checkNetworkStatus() {
        Task {
            switch networkService {
            case .success(let service):
                let connected = await service.checkConnection()
                await MainActor.run {
                    networkStatus = connected ? "연결됨 ✅" : "연결 실패 ❌"
                }

            case .failure(let error):
                await MainActor.run {
                    networkStatus = "에러: \(error.localizedDescription)"
                }

            case .none:
                await MainActor.run {
                    networkStatus = "서비스 없음"
                }
            }
        }
    }
}

#Preview {
    ContentView()
}