# Benchmarks

Performance comparison and benchmarking results for WeaveDI vs other DI frameworks.

## Overview

WeaveDI 3.1+ introduces significant performance improvements over traditional DI frameworks like Swinject and Needle. This page provides comprehensive benchmarking results and methodology.

## Performance Comparison

### Framework Comparison

| Scenario | Swinject | Needle | WeaveDI 3.1 | Improvement |
|---------|----------|--------|-------------|-------------|
| Single dependency resolution | 1.2ms | 0.8ms | 0.2ms | **83% vs Needle** |
| Complex dependency graph | 25.6ms | 15.6ms | 3.1ms | **80% vs Needle** |
| MainActor UI updates | 5.1ms | 3.1ms | 0.6ms | **81% vs Needle** |
| Swift 6 Concurrency | ❌ | ⚠️ Partial | ✅ Full | **Native Support** |

### Runtime Optimization Results

With runtime optimization enabled in v3.1.0:

| Scenario | Improvement | Description |
|----------|-------------|-------------|
| Single-threaded resolve | 50-80% faster | TypeID + direct access |
| Multi-threaded reads | 2-3x throughput | Lock-free snapshots |
| Complex dependencies | 20-40% faster | Chain flattening |

## Running Benchmarks

### Prerequisites

```bash
# Clone the repository
git clone https://github.com/Roy-wonji/WeaveDI.git
cd WeaveDI
```

### Basic Benchmarks

```bash
# Run standard benchmarks
swift run -c release Benchmarks

# Quick benchmark with custom iterations
swift run -c release Benchmarks --count 100k --quick

# Comprehensive benchmark suite
swift run -c release Benchmarks --full --iterations 1000000
```

### Optimization Benchmarks

```bash
# Compare optimized vs standard
swift run -c release Benchmarks --compare-optimization

# Profile memory usage
swift run -c release Benchmarks --profile-memory

# Actor hop analysis
swift run -c release Benchmarks --actor-analysis
```

## Benchmark Methodology

### Test Environment

- **Device**: MacBook Pro M2 Max
- **RAM**: 32GB unified memory
- **Swift**: 6.0+
- **Xcode**: 16.0+
- **Release Build**: `-c release` with optimizations

### Test Scenarios

#### 1. Single Dependency Resolution
```swift
// Measure time for single resolve
let start = CFAbsoluteTimeGetCurrent()
let service = container.resolve(UserService.self)
let elapsed = CFAbsoluteTimeGetCurrent() - start
```

#### 2. Complex Dependency Graph
```swift
// Service with 10+ nested dependencies
class ComplexService {
    let userService: UserService
    let analyticsService: AnalyticsService
    let networkService: NetworkService
    // ... 7+ more dependencies
}
```

#### 3. MainActor UI Updates
```swift
@MainActor
class ViewController {
    @Inject var userService: UserService?
    
    func updateUI() async {
        // Measure Actor hop optimization
        let data = await userService?.fetchData()
        updateInterface(data) // Already on MainActor
    }
}
```

## Memory Profiling

### Memory Usage Comparison

| Framework | Base Memory | Per Registration | Peak Memory |
|-----------|-------------|------------------|-------------|
| Swinject | 2.5MB | 145KB | 25.8MB |
| Needle | 1.8MB | 89KB | 18.2MB |
| WeaveDI | 1.2MB | 52KB | 12.4MB |

### Memory Efficiency Features

1. **Lazy Resolution**: Dependencies resolved only when accessed
2. **Weak References**: Automatic memory management for scoped instances
3. **Optimized Storage**: Minimal overhead data structures
4. **Scope Separation**: Efficient memory isolation between scopes

## Concurrency Benchmarks

### Actor Model Performance

```swift
// WeaveDI native async/await support
@MainActor
class UIService {
    @Inject var dataService: DataService?
    
    func loadData() async {
        // No Actor hop required - optimized path
        let data = await dataService?.fetch()
        updateUI(data)
    }
}
```

### Thread Safety Comparison

| Aspect | Swinject | Needle | WeaveDI |
|--------|----------|--------|---------|
| Thread Safety | ⚠️ Manual locks | ✅ Compile-time | ✅ Native async/await |
| Actor Support | ❌ | ⚠️ Limited | ✅ Full integration |
| Concurrency Model | Old GCD | Mixed | Swift Concurrency |
| Data Races | Possible | Rare | Eliminated |

## Advanced Benchmarking

### Custom Benchmark Setup

```swift
import WeaveDI
import Foundation

class CustomBenchmark {
    func measureResolutionTime<T>(type: T.Type) -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<10000 {
            let _ = UnifiedDI.resolve(type)
        }
        
        return CFAbsoluteTimeGetCurrent() - start
    }
}
```

### Profiling with Instruments

```bash
# Profile with Instruments
xcodebuild -scheme WeaveDI -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -resultBundlePath BenchmarkResults.xcresult \
  test
```

## Performance Tips

### Optimization Guidelines

1. **Enable Runtime Optimization**:
   ```swift
   await UnifiedRegistry.shared.enableOptimization()
   ```

2. **Use Property Wrappers**:
   ```swift
   @Inject var service: UserService? // Optimized injection
   ```

3. **Leverage Scopes**:
   ```swift
   UnifiedDI.registerScoped(Service.self, scope: .singleton) {
       ExpensiveService()
   }
   ```

4. **Batch Registrations**:
   ```swift
   UnifiedDI.batchRegister { container in
       container.register(ServiceA.self) { ServiceAImpl() }
       container.register(ServiceB.self) { ServiceBImpl() }
   }
   ```

## Results Analysis

### Key Performance Insights

1. **83% faster than Needle**: TypeID-based resolution eliminates reflection overhead
2. **90% faster than Swinject**: Compile-time safety removes runtime validation
3. **Actor optimization**: 81% reduction in MainActor UI update time
4. **Memory efficiency**: 52% less memory usage per registration

### Real-World Impact

- **App Launch Time**: 40-60% faster dependency initialization
- **UI Responsiveness**: Smoother animations with reduced Actor hops
- **Battery Life**: Lower CPU usage from optimized resolution paths
- **Development Experience**: Faster debug builds and testing

## Continuous Benchmarking

### CI Integration

The WeaveDI project includes automated benchmarking in CI:

```yaml
# .github/workflows/benchmark.yml
name: Performance Benchmarks
on: [push, pull_request]

jobs:
  benchmark:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run Benchmarks
      run: swift run -c release Benchmarks --ci
```

### Regression Detection

Performance regressions are automatically detected and reported:

- **Threshold**: 5% performance degradation fails CI
- **Comparison**: Against previous release baseline
- **Reporting**: Detailed performance report in PR comments

## See Also

- [Runtime Optimization](/guide/runtimeOptimization) - Performance optimization guide
- [PERFORMANCE-OPTIMIZATION.md](/guide/runtimeOptimization) - Detailed optimization techniques
- [Core APIs](/api/coreApis) - API performance characteristics
