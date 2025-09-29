# @Factory 프로퍼티 래퍼

`@Factory` 프로퍼티 래퍼는 동적 인스턴스 생성을 통한 팩토리 기반 의존성 주입을 제공하여, 프로퍼티에 접근할 때마다 새로운 인스턴스를 생성합니다. 이는 종속성을 캐시하는 `@Inject`와는 근본적으로 다르며, 상태를 가진 객체, 세션 범위 서비스, 또는 독립적인 상태를 가진 새로운 인스턴스가 필요한 시나리오에 이상적입니다.

## 개요

`@Inject`와 달리 해결된 의존성을 싱글톤과 같은 동작으로 캐시하지 않고, `@Factory`는 사용 간 완전한 상태 격리를 보장하는 동적 생성 패턴을 구현합니다. 이는 다음과 같은 상황에서 중요합니다:

- **상태를 가진 서비스**: 공유되어서는 안 되는 내부 상태를 유지하는 객체
- **세션 범위 객체**: 요청 또는 사용자 세션별 인스턴스
- **임시 작업자**: 특정 구성을 가진 단기 실행 처리 객체
- **스레드 안전 작업**: 동시 처리를 위한 독립적인 인스턴스
- **깨끗한 상태 요구사항**: 각 작업마다 재설정된 상태가 필요한 객체

**성능 특성**:
- **메모리 사용량**: 여러 인스턴스로 인한 높은 메모리 사용량
- **생성 오버헤드**: 각 접근마다 작은 인스턴스화 비용 (~0.1-2ms, 객체 복잡성에 따라)
- **가비지 컬렉션**: 인스턴스는 사용 후 수집되어 메모리 누수 방지
- **스레드 안전성**: 각 접근이 독립적인 인스턴스를 얻어 공유 상태 문제 제거

```swift
import WeaveDI

class DataProcessor {
    @Factory var taskManager: TaskManager?
    @Factory var reportGenerator: ReportGenerator?

    func processData() {
        // 각 접근마다 새로운 TaskManager 인스턴스 생성
        let manager1 = taskManager // 새로운 인스턴스
        let manager2 = taskManager // 또 다른 새로운 인스턴스

        manager1?.startTask("Task A")
        manager2?.startTask("Task B") // 독립적인 인스턴스들
    }
}
```

## 기본 사용법

### 간단한 팩토리 주입

**목적**: 각 프로퍼티 접근에서 새로운 인스턴스를 생성하는 기본적인 팩토리 기반 의존성 주입입니다.

**사용 시기**:
- 가변 상태를 유지하는 객체
- 각 작업마다 깨끗한 초기화가 필요한 서비스
- 입력에 따라 자체 구성하는 처리 객체
- 임시 또는 단기 실행 작업자

**성능 영향**:
- **메모리**: 각 접근마다 새로운 인스턴스 생성 (~1-100KB, 객체 크기에 따라)
- **CPU**: 접근당 최소 인스턴스화 오버헤드
- **스레딩**: 독립적인 인스턴스로 인한 스레드 안전성

```swift
class DocumentService {
    @Factory var pdfGenerator: PDFGenerator?

    func createDocument() -> Document? {
        // 각 문서마다 새로운 PDFGenerator 인스턴스
        return pdfGenerator?.generatePDF()
    }
}
```

### 세션 기반 객체와 함께

**목적**: 독립적인 상태 관리와 생명주기 제어가 필요한 세션 또는 요청 범위 객체를 위한 팩토리 주입입니다.

**이점**:
- **상태 격리**: 각 세션이 독립적인 상태를 가짐
- **동시 안전성**: 여러 세션이 동시에 실행 가능
- **리소스 관리**: 세션을 개별적으로 관리하고 정리 가능
- **구성 유연성**: 각 세션이 다른 구성을 가질 수 있음

**사용 사례**:
- HTTP 요청 처리
- 사용자 세션 관리
- 트랜잭션 범위 작업
- 배치 처리 작업

팩토리 주입은 세션이나 요청 범위의 객체에 완벽합니다:

```swift
class APIService {
    @Factory var httpSession: HTTPSession?
    @Factory var requestBuilder: RequestBuilder?

    func makeRequest() async {
        // 각 요청마다 새로운 세션
        guard let session = httpSession,
              let builder = requestBuilder else { return }

        let request = builder.buildRequest()
        await session.execute(request)
    }
}
```

## 튜토리얼의 실제 예제

### CountApp에서 팩토리 패턴

우리 튜토리얼 코드를 기반으로, @Factory가 독립적인 인스턴스 생성에 어떻게 사용되는지 보여줍니다:

```swift
/// 독립적인 카운팅 세션을 위한 팩토리 기반 카운터
class CounterSessionManager {
    @Factory var counterSession: CounterSession?
    @Factory var logger: LoggerProtocol?

    func startNewCountingSession(name: String) async {
        guard let session = counterSession else { return }

        logger?.info("🆕 새로운 카운터 세션 시작: \\(name)")

        // 각 세션은 독립적
        session.sessionName = name
        session.startTime = Date()
        await session.initialize()
    }

    func createMultipleSessions() async {
        // 각 호출마다 새로운 독립적인 세션 생성
        await startNewCountingSession(name: "Session A")
        await startNewCountingSession(name: "Session B")
        await startNewCountingSession(name: "Session C")

        // 모든 세션이 독립적인 인스턴스
    }
}

/// 세션 범위의 카운터 구현
class CounterSession {
    var sessionName: String = ""
    var startTime: Date = Date()
    var currentCount: Int = 0

    @Inject var repository: CounterRepository?
    @Inject var logger: LoggerProtocol?

    func initialize() async {
        logger?.info("📊 세션 '\\(sessionName)' 초기화됨")
        currentCount = await repository?.getCurrentCount() ?? 0
    }

    func increment() async {
        currentCount += 1
        await repository?.saveCount(currentCount)
        logger?.info("⬆️ 세션 '\\(sessionName)': \\(currentCount)")
    }
}
```

### WeatherApp에서 리포트 생성용 팩토리

```swift
/// 새로운 리포트를 위해 팩토리 패턴을 사용하는 날씨 리포트 서비스
class WeatherReportService {
    @Factory var reportGenerator: WeatherReportGenerator?
    @Factory var chartBuilder: WeatherChartBuilder?
    @Inject var weatherService: WeatherServiceProtocol?

    func generateDailyReport(for city: String) async throws -> WeatherReport? {
        guard let generator = reportGenerator,
              let weather = try await weatherService?.fetchCurrentWeather(for: city) else {
            return nil
        }

        // 각 리포트마다 새로운 생성기
        generator.configure(for: .daily)
        return await generator.generateReport(weather: weather)
    }

    func generateWeeklyReport(for city: String) async throws -> WeatherReport? {
        guard let generator = reportGenerator,
              let forecast = try await weatherService?.fetchForecast(for: city) else {
            return nil
        }

        // 다른 구성을 가진 새로운 생성기 인스턴스
        generator.configure(for: .weekly)
        return await generator.generateWeeklyReport(forecast: forecast)
    }

    func createWeatherChart(for city: String) async throws -> WeatherChart? {
        guard let builder = chartBuilder,
              let forecast = try await weatherService?.fetchForecast(for: city) else {
            return nil
        }

        // 각 차트마다 새로운 차트 빌더
        return await builder.buildChart(data: forecast)
    }
}

/// 팩토리로 생성되는 리포트 생성기
class WeatherReportGenerator {
    enum ReportType {
        case daily, weekly, monthly
    }

    private var reportType: ReportType = .daily
    private var generationTime: Date = Date()

    @Inject var logger: LoggerProtocol?

    func configure(for type: ReportType) {
        self.reportType = type
        self.generationTime = Date()
        logger?.info("📋 리포트 생성기 구성: \\(type)")
    }

    func generateReport(weather: Weather) async -> WeatherReport {
        logger?.info("📊 \\(reportType) 리포트 생성 중...")

        return WeatherReport(
            type: reportType,
            city: weather.city,
            temperature: weather.temperature,
            generatedAt: generationTime,
            summary: generateSummary(weather: weather)
        )
    }

    func generateWeeklyReport(forecast: [WeatherForecast]) async -> WeatherReport {
        logger?.info("📈 주간 리포트 생성 중...")

        let avgTemp = forecast.reduce(0.0) { $0 + ($1.maxTemperature + $1.minTemperature) / 2 } / Double(forecast.count)

        return WeatherReport(
            type: .weekly,
            city: forecast.first?.formattedDate ?? "Unknown",
            temperature: avgTemp,
            generatedAt: generationTime,
            summary: "주간 평균 온도: \\(String(format: "%.1f", avgTemp))°C"
        )
    }

    private func generateSummary(weather: Weather) -> String {
        switch reportType {
        case .daily:
            return "\\(weather.city)의 오늘 날씨: \\(weather.description), \\(weather.formattedTemperature)"
        case .weekly:
            return "\\(weather.city)의 주간 날씨 요약"
        case .monthly:
            return "\\(weather.city)의 월간 날씨 요약"
        }
    }
}
```

## Factory vs Inject 비교

### @Factory를 사용해야 하는 경우

**결정 기준**: 상태 관리 요구사항과 생명주기 필요에 따라 `@Factory`와 `@Inject` 중 선택합니다.

**@Factory가 이상적인 경우**:
- **상태를 가진 객체**: 변화하는 내부 상태를 유지하는 객체
- **세션 범위 서비스**: 요청 또는 사용자별 인스턴스
- **구성 가능한 작업자**: 사용마다 다른 구성이 필요한 객체
- **단기 실행 객체**: 임시 처리 객체
- **스레드 안전 요구사항**: 동시 접근을 위한 독립적인 인스턴스

**@Inject가 이상적인 경우**:
- **상태 없는 서비스**: 순수 함수 또는 유틸리티 클래스
- **공유 리소스**: 데이터베이스 연결, 로거, 구성
- **비싼 객체**: 한 번만 초기화해야 하는 무거운 초기화
- **전역 상태**: 애플리케이션 전체 싱글톤 서비스

```swift
class DocumentProcessor {
    // ✅ 상태를 가진 단기 객체에 @Factory 사용
    @Factory var documentBuilder: DocumentBuilder?
    @Factory var validator: DocumentValidator?

    // ✅ 장기 실행, 상태 없는 서비스에 @Inject 사용
    @Inject var documentRepository: DocumentRepository?
    @Inject var logger: LoggerProtocol?

    func processDocument(_ content: String) async {
        // 각 문서마다 새로운 빌더와 검증기
        guard let builder = documentBuilder,
              let validator = validator else { return }

        builder.setContent(content)
        let document = builder.build()

        if validator.isValid(document) {
            // 모든 작업에 공유되는 레포지토리
            await documentRepository?.save(document)
            logger?.info("문서 처리 완료")
        }
    }
}
```

### 메모리 및 성능 고려사항

**메모리 관리 전략**:
- **인스턴스 생명주기**: 팩토리 인스턴스는 온디맨드로 생성되고 가비지 컬렉션 가능
- **메모리 풋프린트**: 여러 인스턴스의 누적 메모리 사용량 고려
- **풀 패턴**: 비싼 객체의 경우 객체 풀링 고려

**성능 최적화 가이드라인**:
- **배치 작업**: 가능한 경우 배치 작업에서 팩토리 인스턴스 재사용
- **리소스 모니터링**: 프로덕션에서 메모리 사용 패턴 모니터링
- **가비지 컬렉션**: 팩토리 인스턴스는 사용 후 즉시 GC 대상

**스레딩 고려사항**:
- **동시성 안전**: 각 스레드가 독립적인 인스턴스를 얻음
- **리소스 경합**: 팩토리 인스턴스 간 공유 상태 없음
- **병렬 처리**: 동기화 없이 동시 작업에 안전

```swift
class PerformanceTestService {
    @Factory var heavyProcessor: HeavyProcessor? // 매번 새로운 인스턴스
    @Inject var cacheService: CacheService?      // 공유 인스턴스

    func processData() {
        // ⚠️ @Factory와 함께 메모리 사용량 고려
        for i in 0..<1000 {
            // 이렇게 하면 1000개의 HeavyProcessor 인스턴스 생성!
            heavyProcessor?.process(data: "item \\(i)")
        }

        // ✅ 더 나은 접근법: 가능할 때 재사용
        guard let processor = heavyProcessor else { return }
        for i in 0..<1000 {
            processor.process(data: "item \\(i)")
        }
    }
}
```

## 구성 및 등록

### 팩토리 의존성 등록

**목적**: 싱글톤 주입과 동일한 등록 API를 사용하여 팩토리 주입용 의존성을 등록합니다.

**주요 차이점**:
- **등록**: `@Inject` 의존성과 동일한 API
- **해결**: 각 `@Factory` 접근에서 새로운 인스턴스 생성
- **생명주기**: 컨테이너는 팩토리 클로저를 관리하며, 인스턴스는 아님
- **스레드 안전성**: 등록은 스레드 안전하며, 인스턴스는 독립적

**등록 패턴**:
- **간단한 등록**: 기본 팩토리 클로저 등록
- **매개변수화된 팩토리**: 구성 매개변수를 받는 팩토리
- **의존성 주입**: 팩토리 클로저가 다른 의존성을 해결할 수 있음

팩토리 의존성은 일반 의존성과 같은 방식으로 등록됩니다:

```swift
// DependencyBootstrap.swift
await WeaveDI.Container.bootstrap { container in
    // 팩토리 주입용 등록
    container.register(TaskManager.self) {
        TaskManagerImpl()
    }

    container.register(ReportGenerator.self) {
        WeatherReportGenerator()
    }

    container.register(DocumentBuilder.self) {
        PDFDocumentBuilder()
    }

    // @Factory가 해결할 때마다 새로운 인스턴스 생성
}
```

### 매개변수를 가진 팩토리

**목적**: 동적 구성을 통한 매개변수화된 인스턴스 생성을 지원하는 고급 팩토리 패턴입니다.

**이점**:
- **동적 구성**: 특정 매개변수로 인스턴스 생성
- **컨텍스트 인식 생성**: 런타임 컨텍스트에 따라 적응하는 팩토리
- **타입 안전성**: 컴파일 타임 매개변수 검증
- **유연한 인스턴스화**: 여러 생성 패턴 지원

**구현 전략**:
- **서비스 팩토리 패턴**: 복잡한 생성 로직을 위한 전용 팩토리 서비스
- **빌더 통합**: 복잡한 객체를 위한 빌더 패턴과 결합
- **의존성 해결**: 생성 중 다른 의존성을 해결하는 팩토리

더 복잡한 팩토리 패턴의 경우, 클로저 기반 팩토리를 사용할 수 있습니다:

```swift
class ServiceFactory {
    @Inject var container: WeaveDI.Container?

    func createTaskManager(for taskType: TaskType) -> TaskManager? {
        // 매개변수에 따라 구성된 인스턴스 생성
        let manager = container?.resolve(TaskManager.self)
        manager?.configure(for: taskType)
        return manager
    }
}
```

## 스레드 안전성

**스레드 안전성 보장**: `@Factory`는 인스턴스 격리와 안전한 해결 메커니즘을 통해 포괄적인 스레드 안전성을 제공합니다.

**안전성 메커니즘**:
- **독립적인 인스턴스**: 각 프로퍼티 접근이 격리된 인스턴스를 생성
- **공유 상태 없음**: 팩토리 인스턴스가 가변 상태를 공유하지 않음
- **스레드 안전 해결**: 컨테이너 해결이 내부적으로 동기화됨
- **동시 접근**: 여러 스레드가 안전하게 팩토리 프로퍼티에 접근 가능

**동시성 이점**:
- **병렬 처리**: 각 스레드가 독립적인 인스턴스를 얻음
- **동기화 불필요**: 수동 스레드 동기화 필요 없음
- **경합 조건 방지**: 인스턴스 격리가 경합 조건 방지
- **확장 가능한 동시성**: 스레드 수에 따른 성능 확장

**성능 특성**:
- **해결 오버헤드**: 해결 중 최소 동기화 접근
- **인스턴스 생성**: 인스턴스 생성 후 동기화 없음
- **메모리 장벽**: 자동 메모리 장벽 처리

@Factory는 스레드 안전하며 다른 큐에서 사용할 수 있습니다:

```swift
class ConcurrentProcessor {
    @Factory var workItem: WorkItem?

    func processConcurrently() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    // 각 작업이 자체 WorkItem 인스턴스를 얻음
                    self.workItem?.execute(id: i)
                }
            }
        }
    }
}
```

## @Factory로 테스팅

### 모의 팩토리 의존성

**테스트 전략**: 팩토리 의존성은 새로운 모의 인스턴스와 상태 격리를 통해 뛰어난 테스트 기능을 제공합니다.

**테스트 이점**:
- **새로운 모의**: 각 테스트가 새로운 모의 인스턴스를 얻음
- **상태 격리**: 테스트가 서로 간섭하지 않음
- **동작 검증**: 생성 패턴과 인스턴스 사용을 검증할 수 있음
- **독립적인 어설션**: 각 테스트가 독립적인 객체 동작을 검증

**모의 패턴**:
- **상태 검증**: 작업 후 모의 상태 검증
- **상호작용 계수**: 생성된 인스턴스 수 추적
- **구성 테스트**: 팩토리 인스턴스가 올바르게 구성되었는지 검증
- **생명주기 테스트**: 인스턴스 생성 및 정리 패턴 테스트

```swift
class FactoryServiceTests: XCTestCase {

    func testDocumentProcessing() async throws {
        // 팩토리 모의 등록
        await WeaveDI.Container.bootstrap { container in
            container.register(DocumentBuilder.self) { MockDocumentBuilder() }
            container.register(DocumentValidator.self) { MockDocumentValidator() }
        }

        let processor = DocumentProcessor()

        // 각 테스트가 새로운 모의 인스턴스를 얻음
        await processor.processDocument("test content")

        // 새로운 인스턴스가 생성되었는지 확인
        XCTAssertNotNil(processor.documentBuilder)
        XCTAssertNotNil(processor.validator)
    }
}

class MockDocumentBuilder: DocumentBuilder {
    private(set) var buildCallCount = 0

    func build() -> Document {
        buildCallCount += 1
        return Document(content: "mock content")
    }
}
```

## 고급 패턴

### 생명주기 관리를 가진 팩토리

**목적**: 팩토리 생성 인스턴스에 대한 고급 생명주기 관리로 추적, 정리, 리소스 관리를 제공합니다.

**생명주기 관리 기능**:
- **인스턴스 추적**: 활성 팩토리 인스턴스 모니터링
- **리소스 정리**: 인스턴스 완료 시 자동 리소스 정리
- **메모리 관리**: 버려진 인스턴스로 인한 메모리 누수 방지
- **성능 모니터링**: 인스턴스 생성 및 소멸 패턴 추적

**구현 전략**:
- **약한 참조**: retain 사이클을 피하기 위한 약한 참조 사용
- **완료 콜백**: 인스턴스 완료를 위한 정리 콜백 등록
- **리소스 풀링**: 비싼 팩토리 인스턴스를 위한 풀링 구현
- **자동 정리**: 객체 해제 중 리소스 정리

**사용 사례**:
- **세션 관리**: 사용자 세션 추적 및 정리
- **리소스 관리**: 데이터베이스 연결 또는 파일 핸들 관리
- **배치 처리**: 배치 처리 작업자의 생명주기 조정
- **임시 서비스**: 임시 서비스 인스턴스의 생명주기 관리

```swift
class ManagedFactoryService {
    @Factory var sessionManager: SessionManager?
    private var activeSessions: [SessionManager] = []

    func createManagedSession() -> SessionManager? {
        guard let session = sessionManager else { return nil }

        // 팩토리로 생성된 인스턴스 추적
        activeSessions.append(session)

        // 정리 설정
        session.onComplete = { [weak self] completedSession in
            self?.cleanupSession(completedSession)
        }

        return session
    }

    private func cleanupSession(_ session: SessionManager) {
        activeSessions.removeAll { $0 === session }
    }

    deinit {
        // 관리되는 모든 세션 정리
        activeSessions.forEach { $0.cleanup() }
    }
}
```

### 빌더 패턴과 함께 팩토리

**목적**: 메서드 체이닝을 통한 유연하고 유창한 객체 생성을 위해 팩토리 주입과 빌더 패턴을 결합합니다.

**패턴 이점**:
- **유창한 인터페이스**: 읽기 쉬운 생성을 위한 구성 메서드 체인
- **유연한 구성**: 여러 구성 시나리오 지원
- **타입 안전성**: 빌더 구성의 컴파일 타임 검증
- **불변 결과**: 빌더 패턴을 통한 불변 객체 생성

**구현 기능**:
- **메서드 체이닝**: 단계별 구성을 위한 유창한 API
- **검증**: 객체 생성 전 빌더가 구성을 검증할 수 있음
- **기본값**: 재정의 가능한 합리적인 기본값 제공
- **복잡한 생성**: 복잡한 객체 초기화 로직 처리

**사용 사례**:
- **보고서 생성**: 복잡한 보고서 구성 및 빌드
- **UI 컴포넌트 생성**: 구성된 UI 컴포넌트 빌드
- **데이터 처리**: 특정 매개변수로 데이터 프로세서 구성
- **서비스 구성**: 복잡한 구성 요구사항을 가진 서비스 빌드

```swift
class ReportBuilderService {
    @Factory var reportBuilder: ReportBuilder?

    func createCustomReport() -> Report? {
        return reportBuilder?
            .setTitle("사용자 정의 리포트")
            .addSection("날씨 데이터")
            .addSection("분석")
            .setFormat(.pdf)
            .build()
    }

    func createSimpleReport() -> Report? {
        return reportBuilder?
            .setTitle("간단한 리포트")
            .setFormat(.text)
            .build()
    }
}
```

## 모범 사례

### 1. 상태를 가진 객체에 팩토리 사용

**가이드라인**: 내부 상태를 유지하거나 각 사용마다 새로운 초기화가 필요한 객체에 `@Factory`를 예약합니다.

**상태를 가진 객체 지표**:
- **가변 프로퍼티**: 생명주기 동안 변화하는 프로퍼티를 가진 객체
- **구성 상태**: 사용마다 다른 구성이 필요한 객체
- **세션 컨텍스트**: 사용자 또는 요청별 컨텍스트를 유지하는 객체
- **처리 상태**: 처리 진행률 또는 중간 결과를 유지하는 객체

**결정 프레임워크**:
- 객체가 상태를 유지하는 경우 → `@Factory` 사용
- 객체가 상태 없는 경우 → `@Inject` 사용
- 상태 격리가 필요한 경우 → `@Factory` 사용
- 공유 상태가 허용되는 경우 → `@Inject` 사용
```swift
// ✅ 좋음 - 새로운 인스턴스가 필요한 상태를 가진 객체
@Factory var userSession: UserSession?
@Factory var shoppingCart: ShoppingCart?
@Factory var gameState: GameState?

// ❌ 피하기 - 상태 없는 서비스 (대신 @Inject 사용)
@Factory var mathUtils: MathUtils? // @Inject을 사용해야 함
```

### 2. 메모리 영향 고려

**메모리 관리 전략**: 특히 자주 접근되는 프로퍼티의 경우 팩토리 주입의 메모리 영향을 신중하게 평가합니다.

**메모리 고려사항**:
- **인스턴스 크기**: 팩토리 생성 객체의 메모리 풋프린트 고려
- **생성 빈도**: 팩토리 프로퍼티에 접근하는 빈도 분석
- **생명주기 지속시간**: 인스턴스가 메모리에 남아 있는 시간 평가
- **누적 사용량**: 모든 팩토리 인스턴스의 총 메모리 사용량 모니터링

**최적화 전략**:
- **인스턴스 재사용**: 단일 작업 내에서 적절한 경우 팩토리 인스턴스 재사용
- **객체 풀링**: 비싼 팩토리 객체를 위한 풀링 구현
- **지연 생성**: 실제로 필요할 때만 인스턴스 생성
- **리소스 정리**: 팩토리 인스턴스의 적절한 정리 보장

**모니터링 및 프로파일링**:
- 메모리 프로파일러를 사용하여 팩토리 인스턴스 생성 모니터링
- 프로덕션 환경에서 할당 패턴 추적
- 과도한 메모리 사용에 대한 알림 설정
- 팩토리 사용 패턴 정기 검토
```swift
class MemoryAwareService {
    @Factory var heavyObject: HeavyObject?

    func processItems(_ items: [String]) {
        // ❌ 나쁨 - 많은 인스턴스 생성
        items.forEach { item in
            heavyObject?.process(item)
        }

        // ✅ 더 좋음 - 가능할 때 재사용
        guard let processor = heavyObject else { return }
        items.forEach { item in
            processor.process(item)
        }
    }
}
```

### 3. 팩토리 사용법 문서화

**문서화 전략**: 팩토리 주입이 사용되는 이유와 제공하는 동작을 명확히 문서화하여 유지보수자가 설계 결정을 이해할 수 있도록 합니다.

**문서화 요소**:
- **목적**: 팩토리 주입이 필요한 이유 설명
- **상태 관리**: 상태 격리 이점 설명
- **생명주기**: 예상되는 인스턴스 생명주기 문서화
- **성능**: 성능 영향 언급

**문서화 모범 사례**:
- 명확하고 설명적인 주석 사용
- 팩토리와 싱글톤 주입 간의 트레이드오프 설명
- 특별한 생명주기 요구사항 문서화
- 적절한 사용 패턴의 예제 제공
```swift
class DocumentService {
    /// 깨끗한 상태를 보장하기 위해 각 문서마다 새로운 PDF 생성기 생성
    @Factory var pdfGenerator: PDFGenerator?

    /// 모든 문서 작업을 위한 공유 레포지토리
    @Inject var documentRepository: DocumentRepository?
}
```

### 4. 팩토리 동작 테스트

**테스트 전략**: 팩토리 주입이 예상대로 새로운 인스턴스를 생성하고 상태 격리가 올바르게 작동하는지 검증합니다.

**테스트 요구사항**:
- **인스턴스 고유성**: 각 접근이 새로운 인스턴스를 생성하는지 검증
- **상태 격리**: 인스턴스가 상태를 공유하지 않는지 확인
- **생성 패턴**: 팩토리 생성이 예상 패턴을 따르는지 테스트
- **리소스 관리**: 적절한 정리 및 리소스 관리 검증

**테스트 카테고리**:
- **동작 테스트**: 팩토리 생성 동작 검증
- **성능 테스트**: 팩토리 생성 성능 측정
- **메모리 테스트**: 메모리 사용 패턴 검증
- **동시성 테스트**: 스레드 안전성 및 동시 접근 테스트

**테스트 도구**:
- 인스턴스 고유성을 위한 객체 식별성 비교 사용
- 모의 객체에 생성 카운터 구현
- 팩토리 테스트 중 메모리 사용량 모니터링
- 스레드 안전성 검증을 위한 동시 테스트 프레임워크 사용
```swift
func testFactoryCreatesNewInstances() {
    let service = DocumentService()

    let generator1 = service.pdfGenerator
    let generator2 = service.pdfGenerator

    // 다른 인스턴스인지 확인
    XCTAssertNotIdentical(generator1, generator2)
}
```

## 성능 고려사항

### 메모리 관리

**가비지 컬렉션 이점**:
- **자동 정리**: 팩토리 인스턴스는 캐시되지 않아 자동 가비지 컬렉션 가능
- **메모리 효율성**: 사용하지 않는 인스턴스는 즉시 수집 가능
- **메모리 누수 없음**: 팩토리 인스턴스에 대한 영구 참조 없음
- **예측 가능한 메모리 사용**: 메모리 사용 패턴이 더 예측 가능

**메모리 사용 가이드라인**:
- **비싼 객체**: 비싼 객체를 자주 생성하는 것에 주의
- **배치 작업**: 배치 작업을 위한 인스턴스 재사용 고려
- **리소스 모니터링**: 프로덕션에서 메모리 사용 패턴 모니터링
- **객체 풀링**: 적절한 경우 무거운 팩토리 객체를 위한 풀링 구현

**성능 최적화 전략**:
- **프로파일링**: 성능 병목 지점 식별을 위한 정기 프로파일링
- **지연 로딩**: 실제로 필요할 때까지 팩토리 인스턴스 생성 연기
- **리소스 캐싱**: 팩토리 인스턴스가 사용하는 비싼 리소스 캐싱
- **할당 패턴**: 더 나은 가비지 컬렉션을 위한 할당 패턴 최적화

### 최적화 팁

**성능 최적화 가이드라인**: 팩토리 주입의 이점과 성능 요구사항의 균형을 맞추기 위한 전략적 최적화를 구현합니다.

**최적화 전략**:
- **객체 풀링**: 풀링 메커니즘을 통한 비싼 객체 재사용
- **지연 평가**: 절대적으로 필요할 때까지 인스턴스 생성 연기
- **리소스 공유**: 팩토리 인스턴스 간 비싼 리소스 공유
- **배치 처리**: 인스턴스 생성 오버헤드를 줄이기 위한 작업 그룹화

**모니터링 및 메트릭**:
- **생성률**: 팩토리 인스턴스 생성 빈도 모니터링
- **메모리 사용량**: 메모리 소비 패턴 추적
- **성능 영향**: 팩토리 주입의 성능 영향 측정
- **리소스 활용**: 팩토리 인스턴스 간 리소스 활용 모니터링
```swift
class OptimizedFactoryService {
    @Factory var expensiveProcessor: ExpensiveProcessor?
    private var processorPool: [ExpensiveProcessor] = []

    func getOptimizedProcessor() -> ExpensiveProcessor? {
        // 비싼 팩토리 객체에 풀링 사용
        if let pooled = processorPool.popLast() {
            pooled.reset()
            return pooled
        }
        return expensiveProcessor
    }

    func returnProcessor(_ processor: ExpensiveProcessor) {
        processorPool.append(processor)
    }
}
```

## 일반적인 함정

### 1. 팩토리 남용

**문제**: 싱글톤 동작의 이점을 얻을 수 있는 상태 없는 서비스에 `@Factory`를 사용하여 불필요한 객체 생성과 메모리 오버헤드를 초래합니다.

**증상**:
- 상태 없는 서비스의 많은 인스턴스 생성
- 단순한 유틸리티를 위한 불필요한 메모리 할당
- 과도한 인스턴스화로 인한 성능 저하
- 리소스 공유 기회 놓침

**해결 전략**:
- **상태 요구사항 평가**: 객체가 정말로 독립적인 상태가 필요한지 신중히 평가
- **@Inject를 기본값으로**: 상태 격리가 필요하지 않은 경우 `@Inject`를 기본 선택으로 사용
- **성능 분석**: 팩토리 vs 싱글톤 주입의 성능 영향 측정
- **설계 검토**: 코드 검토 중 의존성 주입 선택 검토

**결정 가이드라인**:
- 가변 상태를 가짐 → `@Factory` 고려
- 상태 없음 → `@Inject` 사용
- 생성 비용이 비쌈 → `@Inject` 선호
- 사용마다 구성이 필요함 → `@Factory` 고려
```swift
// ❌ 나쁨 - 상태 없는 서비스에 팩토리 사용
@Factory var logger: Logger? // @Inject을 사용해야 함

// ✅ 좋음 - 상태를 가진 객체에 팩토리 사용
@Factory var dataProcessor: DataProcessor?
```

### 2. 팩토리 생명주기 관리하지 않기

**문제**: 적절한 생명주기 관리 없이 많은 팩토리 인스턴스를 생성하여 메모리 누수, 리소스 고갈 또는 성능 저하를 초래합니다.

**증상**:
- 지속적으로 증가하는 메모리 사용량
- 해제되지 않는 리소스 핸들
- 시간이 지나면서 성능 저하
- 과도한 가비지 컬렉션 압박

**근본 원인**:
- **과도한 생성**: 타이트한 루프에서 새로운 인스턴스 생성
- **정리 없음**: 팩토리 인스턴스가 보유한 리소스를 적절히 해제하지 않음
- **리소스 누수**: 비싼 리소스를 보유하는 팩토리 인스턴스
- **잘못된 사용 패턴**: 빈번한 작업에 팩토리 주입을 부적절하게 사용

**해결 전략**:
- **인스턴스 재사용**: 작업 범위 내에서 팩토리 인스턴스 재사용
- **리소스 관리**: 팩토리 인스턴스에서 적절한 리소스 정리 구현
- **사용 패턴**: 팩토리 사용 패턴 검토 및 최적화
- **모니터링**: 인스턴스 생성 및 리소스 사용 패턴 모니터링

**모범 사례**:
- 단일 작업 내에서 팩토리 인스턴스 캐시
- 팩토리 인스턴스 해제자에서 적절한 리소스 정리 구현
- retain 사이클을 피하기 위한 약한 참조 사용
- 생명주기 문제 식별을 위한 정기 프로파일링
```swift
// ❌ 나쁨 - 정리 없이 많은 인스턴스 생성
func processLargeDataset() {
    for item in largeDataset {
        dataProcessor?.process(item) // 매번 새로운 인스턴스 생성
    }
}

// ✅ 좋음 - 적절할 때 인스턴스 재사용
func processLargeDataset() {
    guard let processor = dataProcessor else { return }
    for item in largeDataset {
        processor.process(item)
    }
}
```

## 참고 자료

- [@Inject 프로퍼티 래퍼](./inject.md) - 싱글톤 형태의 주입
- [@SafeInject 프로퍼티 래퍼](./safeInject.md) - 보장된 주입
- [프로퍼티 래퍼 가이드](../guide/propertyWrappers.md) - 모든 프로퍼티 래퍼의 종합 가이드