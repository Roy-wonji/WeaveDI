# Building Your First App with WeaveDI

Create a complete iOS app from scratch using WeaveDI. This tutorial builds a real-world Weather App demonstrating best practices.

## 🎯 Project Overview

We'll build a Weather App with:
- **MVVM Architecture**: Clean separation of concerns
- **WeaveDI Integration**: Proper dependency injection
- **Swift Concurrency**: Modern async/await patterns
- **Error Handling**: Robust error management
- **Testing**: Unit and integration tests

## 📱 App Features

- Current weather display
- 5-day forecast
- Location-based weather
- Offline caching
- Pull-to-refresh
- Error states with retry

## 🏗️ Project Setup

```bash
# Create new iOS project
# File → New → Project → iOS → App
# Product Name: WeatherApp
# Interface: SwiftUI
# Language: Swift
```

Add WeaveDI dependency:
```swift
dependencies: [
    .package(url: "https://github.com/Roy-wonji/WeaveDI.git", from: "3.1.0")
]
```

## 🔧 Step-by-Step Implementation

### Step 1: Project Architecture Setup

First, let's set up the project folder structure:

```
WeatherApp/
├── App/
│   ├── WeatherApp.swift          // App entry point
│   └── DependencyBootstrap.swift // DI setup
├── Views/
│   ├── ContentView.swift         // Main view
│   ├── WeatherView.swift         // Weather display
│   └── CounterView.swift         // Counter demo
├── ViewModels/
│   ├── WeatherViewModel.swift    // Weather logic
│   └── CounterViewModel.swift    // Counter logic
├── Services/
│   ├── WeatherService.swift      // Weather API
│   ├── LocationService.swift     // GPS handling
│   └── LoggingService.swift      // App logging
├── Models/
│   ├── Weather.swift             // Weather data
│   └── Location.swift            // Location data
└── Repositories/
    ├── WeatherRepository.swift   // Weather data layer
    └── CounterRepository.swift   // Counter persistence
```

### Step 2: Core App Setup with WeaveDI

Create the main app file with WeaveDI integration:

```swift
// WeatherApp.swift - Complete App Entry Point using actual tutorial patterns
import SwiftUI
import WeaveDI

@main
struct WeatherApp: App {
    init() {
        // Initialize all dependencies on app startup
        Task {
            await setupDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Additional setup when UI is ready
                    await finalizeAppSetup()
                }
        }
    }

    /// Setup all app dependencies using WeaveDI
    private func setupDependencies() async {
        await DependencyBootstrap.initialize()
    }

    /// Final app setup after UI is ready
    private func finalizeAppSetup() async {
        // Preload critical data
        print("📱 App ready for user interaction")
    }
}

// DependencyBootstrap.swift - Centralized DI Configuration
import Foundation
import WeaveDI

class DependencyBootstrap {

    @DIActor
    static func initialize() async {
        print("🚀 Starting app dependency initialization...")

        // Setup logging first (needed by other services)
        await setupLogging()

        // Setup core services in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await setupLocationService() }
            group.addTask { await setupWeatherService() }
            group.addTask { await setupRepositories() }
        }

        print("✅ All dependencies initialized successfully")
    }

    @DIActor
    private static func setupLogging() async {
        let logger = ConsoleLogger()
        await DIActor.shared.register(LoggerProtocol.self) {
            logger
        }
        print("📝 Logging service registered")
    }

    @DIActor
    private static func setupLocationService() async {
        let service = CoreLocationService()
        await DIActor.shared.register(LocationService.self) {
            service
        }
        print("📍 Location service registered")
    }

    @DIActor
    private static func setupWeatherService() async {
        let service = OpenWeatherMapService()
        await DIActor.shared.register(WeatherService.self) {
            service
        }
        print("🌤️ Weather service registered")
    }

    @DIActor
    private static func setupRepositories() async {
        // Counter repository (from tutorial examples)
        let counterRepo = UserDefaultsCounterRepository()
        await DIActor.shared.register(CounterRepository.self) {
            counterRepo
        }

        // Weather repository
        let weatherRepo = CoreDataWeatherRepository()
        await DIActor.shared.register(WeatherRepository.self) {
            weatherRepo
        }

        print("🗄️ Repositories registered")
    }
}
```

### Step 3: Creating the Counter App (From Actual Tutorial Code)

Let's implement the famous CountApp using real tutorial code:

```swift
// CounterView.swift - Complete Counter Implementation from WeaveDI tutorials
import SwiftUI
import WeaveDI

struct CounterView: View {
    @State private var count = 0
    @State private var isLoading = false
    @State private var history: [CounterHistory] = []

    // WeaveDI property wrapper injection
    @Inject var counterRepository: CounterRepository?
    @Inject var logger: LoggerProtocol?

    var body: some View {
        VStack(spacing: 20) {
            Text("WeaveDI Counter")
                .font(.largeTitle)
                .fontWeight(.bold)

            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                Text("\(count)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.blue)
            }

            HStack(spacing: 20) {
                CounterButton("-", color: .red) {
                    await decrementCounter()
                }

                CounterButton("+", color: .green) {
                    await incrementCounter()
                }
            }

            // History section
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent History")
                        .font(.headline)
                        .padding(.top)

                    ForEach(history.suffix(5), id: \.timestamp) { entry in
                        HStack {
                            Text(entry.action)
                                .foregroundColor(entry.action == "Increase" ? .green : .red)
                            Spacer()
                            Text("\(entry.count)")
                                .fontWeight(.bold)
                            Text(entry.formattedTime)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            Button("Show Full History") {
                Task {
                    await loadHistory()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .task {
            await loadInitialData()
        }
    }

    // MARK: - Actions (using actual repository pattern from tutorials)

    @MainActor
    private func loadInitialData() async {
        isLoading = true
        count = await counterRepository?.getCurrentCount() ?? 0
        await loadHistory()
        isLoading = false
        logger?.info("📊 Initial count loaded: \(count)")
    }

    @MainActor
    private func incrementCounter() async {
        isLoading = true
        count += 1
        await counterRepository?.saveCount(count)
        await loadHistory()
        isLoading = false
        logger?.info("⬆️ Counter incremented: \(count)")
    }

    @MainActor
    private func decrementCounter() async {
        isLoading = true
        count -= 1
        await counterRepository?.saveCount(count)
        await loadHistory()
        isLoading = false
        logger?.info("⬇️ Counter decremented: \(count)")
    }

    private func loadHistory() async {
        history = await counterRepository?.getCountHistory() ?? []
    }
}

// CounterButton.swift - Reusable async button component
struct CounterButton: View {
    let title: String
    let color: Color
    let action: () async -> Void

    var body: some View {
        Button(title) {
            Task {
                await action()
            }
        }
        .font(.title)
        .frame(width: 50, height: 50)
        .background(color)
        .foregroundColor(.white)
        .clipShape(Circle())
    }
}
```

### Step 4: Service Layer Implementation (Real Tutorial Code)

Let's implement the services using actual patterns from WeaveDI tutorials:

```swift
// LoggingService.swift - From Tutorial-MeetWeaveDI-02-01.swift
import Foundation
import LogMacro

protocol LoggerProtocol: Sendable {
    var sessionId: String { get }
    func info(_ message: String)
    func error(_ message: String)
    func debug(_ message: String)
}

final class ConsoleLogger: LoggerProtocol {
    let sessionId: String

    init() {
        // Generate new session ID each time (Factory pattern essence!)
        self.sessionId = UUID().uuidString.prefix(8).uppercased().description
        print("📝 [Logger] New session started: \(sessionId)")
    }

    func info(_ message: String) {
        print("📝 [\(sessionId)] INFO: \(message)")
    }

    func error(_ message: String) {
        print("📝 [\(sessionId)] ERROR: \(message)")
    }

    func debug(_ message: String) {
        print("📝 [\(sessionId)] DEBUG: \(message)")
    }
}

// CounterRepository.swift - From Tutorial-MeetWeaveDI-04-01.swift
import Foundation

/// Repository protocol for counter data storage abstraction
protocol CounterRepository: Sendable {
    func getCurrentCount() async -> Int
    func saveCount(_ count: Int) async
    func getCountHistory() async -> [CounterHistory]
}

/// UserDefaults-based repository implementation
final class UserDefaultsCounterRepository: CounterRepository {
    private let userDefaults = UserDefaults.standard
    private let countKey = "saved_counter_value"
    private let historyKey = "counter_history"

    func getCurrentCount() async -> Int {
        let count = userDefaults.integer(forKey: countKey)
        print("💾 [Repository] Loading saved count: \(count)")
        return count
    }

    func saveCount(_ count: Int) async {
        userDefaults.set(count, forKey: countKey)

        // Add to history as well
        var history = await getCountHistory()
        let newEntry = CounterHistory(
            count: count,
            timestamp: Date(),
            action: count > (history.last?.count ?? 0) ? "Increase" : "Decrease"
        )
        history.append(newEntry)

        // Keep only recent 10 entries
        if history.count > 10 {
            history = Array(history.suffix(10))
        }

        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: historyKey)
        }

        print("💾 [Repository] Count saved: \(count)")
    }

    func getCountHistory() async -> [CounterHistory] {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([CounterHistory].self, from: data) else {
            return []
        }
        return history
    }
}

struct CounterHistory: Codable, Sendable {
    let count: Int
    let timestamp: Date
    let action: String

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// WeatherService.swift - Real weather service implementation
import Foundation

protocol WeatherService: Sendable {
    func getCurrentWeather(for location: Location) async throws -> Weather
    func getForecast(for location: Location) async throws -> [Weather]
}

final class OpenWeatherMapService: WeatherService {
    private let apiKey = "your_api_key_here"
    private let baseURL = "https://api.openweathermap.org/data/2.5"

    @Inject var logger: LoggerProtocol?

    func getCurrentWeather(for location: Location) async throws -> Weather {
        logger?.info("🌤️ Fetching current weather for: \(location.name)")

        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Mock weather data
        let weather = Weather(
            id: UUID(),
            location: location,
            temperature: Double.random(in: 15...30),
            condition: "Sunny",
            humidity: Int.random(in: 30...80),
            windSpeed: Double.random(in: 5...20),
            timestamp: Date()
        )

        logger?.info("✅ Weather data fetched successfully")
        return weather
    }

    func getForecast(for location: Location) async throws -> [Weather] {
        logger?.info("📅 Fetching 5-day forecast for: \(location.name)")

        // Simulate API call
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Mock forecast data
        let forecast = (1...5).map { day in
            Weather(
                id: UUID(),
                location: location,
                temperature: Double.random(in: 15...30),
                condition: ["Sunny", "Cloudy", "Rainy", "Partly Cloudy"].randomElement()!,
                humidity: Int.random(in: 30...80),
                windSpeed: Double.random(in: 5...20),
                timestamp: Calendar.current.date(byAdding: .day, value: day, to: Date())!
            )
        }

        logger?.info("✅ Forecast data fetched successfully")
        return forecast
    }
}

// LocationService.swift - GPS and location handling
import CoreLocation

protocol LocationService: Sendable {
    func getCurrentLocation() async throws -> Location
    func requestLocationPermission() async -> Bool
}

final class CoreLocationService: NSObject, LocationService, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    @Inject var logger: LoggerProtocol?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func getCurrentLocation() async throws -> Location {
        logger?.info("📍 Requesting current location")

        let clLocation = try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }

        let location = Location(
            id: UUID(),
            name: "Current Location",
            latitude: clLocation.coordinate.latitude,
            longitude: clLocation.coordinate.longitude
        )

        logger?.info("✅ Location obtained: \(location.latitude), \(location.longitude)")
        return location
    }

    func requestLocationPermission() async -> Bool {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            return false
        case .denied, .restricted:
            logger?.error("❌ Location permission denied")
            return false
        case .authorizedWhenInUse, .authorizedAlways:
            logger?.info("✅ Location permission granted")
            return true
        @unknown default:
            return false
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}
```

### Step 5: Data Models

```swift
// Weather.swift - Weather data model
import Foundation

struct Weather: Codable, Identifiable, Sendable {
    let id: UUID
    let location: Location
    let temperature: Double
    let condition: String
    let humidity: Int
    let windSpeed: Double
    let timestamp: Date

    var temperatureString: String {
        "\(Int(temperature))°C"
    }

    var windSpeedString: String {
        "\(Int(windSpeed)) km/h"
    }

    var humidityString: String {
        "\(humidity)%"
    }
}

// Location.swift - Location data model
import Foundation

struct Location: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
}
```

### Step 6: Main Content View Integration

```swift
// ContentView.swift - Main app view with tab navigation
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CounterView()
                .tabItem {
                    Image(systemName: "number")
                    Text("Counter")
                }

            WeatherView()
                .tabItem {
                    Image(systemName: "cloud.sun")
                    Text("Weather")
                }
        }
    }
}

// WeatherView.swift - Weather display using WeaveDI
import SwiftUI

struct WeatherView: View {
    @StateObject private var viewModel = WeatherViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Loading weather...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Error: \(error)")
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await viewModel.loadWeather()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let weather = viewModel.currentWeather {
                    VStack(spacing: 16) {
                        Text(weather.location.name)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(weather.temperatureString)
                            .font(.system(size: 48, weight: .light))

                        Text(weather.condition)
                            .font(.title2)
                            .foregroundColor(.secondary)

                        HStack(spacing: 40) {
                            VStack {
                                Text("Humidity")
                                    .font(.caption)
                                Text(weather.humidityString)
                                    .fontWeight(.semibold)
                            }

                            VStack {
                                Text("Wind")
                                    .font(.caption)
                                Text(weather.windSpeedString)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Weather")
            .task {
                await viewModel.loadWeather()
            }
            .refreshable {
                await viewModel.loadWeather()
            }
        }
    }
}

// WeatherViewModel.swift - MVVM pattern with WeaveDI
import Foundation
import SwiftUI

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var currentWeather: Weather?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Inject var weatherService: WeatherService?
    @Inject var locationService: LocationService?
    @Inject var logger: LoggerProtocol?

    func loadWeather() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get current location
            guard let locationSvc = locationService else {
                throw WeatherError.serviceUnavailable
            }

            let location = try await locationSvc.getCurrentLocation()

            // Fetch weather data
            guard let weatherSvc = weatherService else {
                throw WeatherError.serviceUnavailable
            }

            let weather = try await weatherSvc.getCurrentWeather(for: location)
            self.currentWeather = weather

            logger?.info("✅ Weather loaded successfully")

        } catch {
            self.errorMessage = error.localizedDescription
            logger?.error("❌ Failed to load weather: \(error)")
        }

        isLoading = false
    }
}

enum WeatherError: Error, LocalizedError {
    case serviceUnavailable
    case locationDenied
    case networkError

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Weather service is unavailable"
        case .locationDenied:
            return "Location permission denied"
        case .networkError:
            return "Network error occurred"
        }
    }
}
```

## 🧪 Testing Your App

### Unit Testing with WeaveDI

```swift
// WeatherViewModelTests.swift - Testing with dependency injection
import XCTest
@testable import WeatherApp
import WeaveDI

final class WeatherViewModelTests: XCTestCase {

    override func setUpWithError() throws {
        // Setup test dependencies
        WeaveDI.Container.shared.removeAll()
    }

    func testWeatherLoading() async throws {
        // Given: Mock services
        let mockWeatherService = MockWeatherService()
        let mockLocationService = MockLocationService()
        let mockLogger = MockLogger()

        // Register mocks
        WeaveDI.Container.shared.register(WeatherService.self, instance: mockWeatherService)
        WeaveDI.Container.shared.register(LocationService.self, instance: mockLocationService)
        WeaveDI.Container.shared.register(LoggerProtocol.self, instance: mockLogger)

        // When: Load weather
        let viewModel = WeatherViewModel()
        await viewModel.loadWeather()

        // Then: Verify results
        XCTAssertNotNil(viewModel.currentWeather)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
}

// Mock implementations for testing
class MockWeatherService: WeatherService {
    func getCurrentWeather(for location: Location) async throws -> Weather {
        return Weather(
            id: UUID(),
            location: location,
            temperature: 25.0,
            condition: "Sunny",
            humidity: 60,
            windSpeed: 10.0,
            timestamp: Date()
        )
    }

    func getForecast(for location: Location) async throws -> [Weather] {
        return []
    }
}

class MockLocationService: LocationService {
    func getCurrentLocation() async throws -> Location {
        return Location(
            id: UUID(),
            name: "Test Location",
            latitude: 37.7749,
            longitude: -122.4194
        )
    }

    func requestLocationPermission() async -> Bool {
        return true
    }
}

class MockLogger: LoggerProtocol {
    let sessionId = "TEST-SESSION"
    private var logs: [String] = []

    func info(_ message: String) { logs.append("INFO: \(message)") }
    func error(_ message: String) { logs.append("ERROR: \(message)") }
    func debug(_ message: String) { logs.append("DEBUG: \(message)") }
}
```

## 🚀 Performance Tips

1. **Lazy Loading**: Use `@Factory` for services that create new instances
2. **Caching**: Implement caching in your repositories
3. **Background Processing**: Use `@DIActor` for heavy operations
4. **Memory Management**: Use weak references where appropriate

## 🎉 Congratulations!

You've built a complete iOS app with:
- ✅ **WeaveDI Integration**: Proper dependency injection throughout
- ✅ **Counter App**: Real tutorial code implementation
- ✅ **Weather Features**: Practical real-world functionality
- ✅ **MVVM Architecture**: Clean separation of concerns
- ✅ **Testing Setup**: Unit tests with mocked dependencies
- ✅ **Error Handling**: Robust error management
- ✅ **Performance Optimization**: Best practices applied

Your app demonstrates all the key concepts of modern iOS development with WeaveDI!

Check back soon for the complete tutorial!

---

📖 **Related**: [Getting Started](/tutorial/gettingStarted) | [Property Wrappers](/tutorial/propertyWrappers)