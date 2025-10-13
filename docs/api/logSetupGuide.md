# WeaveDI Log Setup Guide

> 🚀 Quick setup and usage guide for WeaveDI's new logging system

## 🚀 Quick Setup

### 1. Basic Log Configuration (30 seconds)

```swift
import WeaveDI

// Add to AppDelegate or app startup
class AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // 🔧 Development setup - show all logs
        #if DEBUG
        UnifiedDI.setLogLevel(.all)
        #else
        // 🏭 Release setup - errors only
        UnifiedDI.setLogLevel(.errors)
        #endif

        return true
    }
}
```

### 2. SwiftUI Project Setup

```swift
import SwiftUI
import WeaveDI

@main
struct MyApp: App {
    init() {
        // Setup logging
        setupLogging()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupLogging() {
        #if DEBUG
        UnifiedDI.setLogLevel(.all)
        #else
        UnifiedDI.setLogLevel(.errors)
        #endif
    }
}
```

---

## 🏗️ Environment-based Configuration

### Development Environment

```swift
// Enable all logs + monitoring
func setupDevelopmentLogging() {
    UnifiedDI.setLogLevel(.all)

    // Start detailed monitoring
    Task {
        await UnifiedDI.startDevelopmentMonitoring()
    }
}
```

### Testing Environment

```swift
// Show only required logs for testing
func setupTestingLogging() {
    UnifiedDI.setLogLevel(.registration)  // Registration process only
    UnifiedDI.setLogSeverity(.info)       // Info level and above
}
```

### Production Environment

```swift
// Minimal logging
func setupProductionLogging() {
    UnifiedDI.setLogLevel(.errors)  // Errors only

    Task {
        await UnifiedDI.startProductionMonitoring()  // Lightweight monitoring
    }
}
```

---

## ⚙️ Advanced Configuration

### 1. Channel-based Fine Control

```swift
// More granular control with DILogger
DILogger.configure(
    level: .all,                    // All channels
    severityThreshold: .warning     // Warning and above
)

// Specific channels only
UnifiedDI.setLogLevel(.performance)  // Performance related only
UnifiedDI.setLogLevel(.health)       // Health checks only
```

### 2. Runtime Log Level Changes

```swift
// Change log levels during app runtime
class DebugSettings {
    static func enableVerboseLogging() {
        DILogger.configure(level: .all, severityThreshold: .debug)
    }

    static func enableErrorsOnly() {
        DILogger.configure(level: .errorsOnly, severityThreshold: .error)
    }

    static func disableLogging() {
        DILogger.configure(level: .off)
    }
}
```

### 3. Custom Log Macro Usage

```swift
// Performance-optimized logging using LogMacro
import LogMacro

class MyService {
    func doSomething() {
        // Compile-time optimized logs
        UnifiedDI.logInfo(channel: .general, "Task started")

        // Perform work...

        UnifiedDI.logInfo(channel: .general, "Task completed")
    }
}
```

---

## 💡 Real-world Examples

### Example 1: Creating Dependency Injection Modules

```swift
import WeaveDI

class NetworkModule {
    static func register() {
        // Logs are automatically recorded
        UnifiedDI.register(NetworkService.self) {
            NetworkServiceImpl()
        }
        // Output: "✅ Successfully registered NetworkService"

        UnifiedDI.register(APIClient.self) {
            APIClientImpl()
        }
        // Output: "✅ Successfully registered APIClient"
    }
}

class UserModule {
    static func register() {
        UnifiedDI.register(UserRepository.self) {
            let networkService = UnifiedDI.resolve(NetworkService.self)
            return UserRepositoryImpl(networkService: networkService)
        }
        // Output: "✅ Successfully resolved NetworkService (took 0.12ms)"
        // Output: "✅ Successfully registered UserRepository"
    }
}
```

### Example 2: Health Checks and Monitoring

```swift
class DIHealthManager {
    static func performHealthCheck() async {
        // Execute health check
        let healthStatus = await UnifiedDI.performHealthCheck()

        if healthStatus.isHealthy {
            print("🟢 DI Container Status: Healthy")
        } else {
            print("🔴 DI Container Status: Issues Found")
            print("Issues: \(healthStatus.issues)")
        }

        // Generate performance report
        let report = await UnifiedDI.generateMonitoringReport()
        print("📊 Performance Report: \(report.recommendations)")
    }
}
```

### Example 3: Log Output Optimization

```swift
// Code auto-converted by convert_to_logmacro.py script
class OptimizedService {
    func processData() {
        #logInfo("🔄 Data processing started")    // Original: print("🔄 Data processing started")

        // Processing logic...

        #logInfo("✅ Data processing completed")    // Original: print("✅ Data processing completed")
    }

    func handleError() {
        #logError("❌ Error occurred during processing")  // Original: print("❌ Error occurred during processing")
    }
}
```

---

## 🔧 Troubleshooting

### Q1: Logs are not showing

**Solution:**
```swift
// 1. Check log level
let config = UnifiedDI.getLogConfiguration()
print("Current log level: \(config.level)")
print("Current severity: \(config.severity)")

// 2. Force enable all logs
UnifiedDI.setLogLevel(.all)
DILogger.configure(level: .all, severityThreshold: .debug)
```

### Q2: Too many logs are showing

**Solution:**
```swift
// Show errors only
UnifiedDI.setLogLevel(.errors)

// Or specific channels only
UnifiedDI.setLogLevel(.performance)  // Performance related only
```

### Q3: Logs showing in release builds

**Solution:**
```swift
// Check environment-based conditional setup
#if DEBUG
UnifiedDI.setLogLevel(.all)
#else
UnifiedDI.setLogLevel(.off)  // Turn off completely
#endif
```

### Q4: LogMacro not found error

**Solution:**
1. Verify LogMacro dependency in Package.swift
2. Add `import LogMacro`
3. Clean build project (`⌘ + Shift + K`)

---

## 📚 Additional Resources

- **Detailed Documentation**: [logging.md](./logging.md)
- **Health Checks**: [healthCheck.md](./healthCheck.md)
- **Performance Monitoring**: [performanceMonitoring.md](./performanceMonitoring.md)

---

## 🎯 Quick Checklist

- [ ] Call `UnifiedDI.setLogLevel()` at app startup
- [ ] Set log levels for development/release environments
- [ ] Add LogMacro import
- [ ] Start monitoring if needed
- [ ] Configure health checks (optional)

**Setup Complete! 🎉**

You can now effectively monitor and debug dependency injection using WeaveDI's powerful logging system.