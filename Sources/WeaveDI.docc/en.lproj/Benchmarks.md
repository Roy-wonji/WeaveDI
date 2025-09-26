# Performance Benchmarks

A simple benchmark guide for quickly checking WeaveDI's resolve performance. You can verify p50/p95/p99 and total execution time through the Benchmarks execution target, and explore optimal points based on debounce intervals.

## How to Run

- Single combination (recommended):
```bash
swift run -c release Benchmarks -- --count 100000 --debounce 100
```
- All combinations (default):
```bash
swift run -c release Benchmarks
```
- Quick exit (first combination only):
```bash
swift run -c release Benchmarks -- --quick
```
- CSV saving and charting (optional):
```bash
swift run -c release Benchmarks -- --count 100000 --debounce 100 --csv bench.csv
python3 Scripts/plot_bench.py --csv bench.csv --out bench_plot
```

## Sample Results

Below is sample output measured at 10k/100k/1M × 50/100/200ms debounce (results may vary by environment).

```
📊 Bench: counts=[10000, 100000, 1000000], debounces=[50, 100, 200] (ms)
debounce= 50ms, n=    10000 | total=   23.30ms | p50= 0.002 p95= 0.003 p99= 0.005
debounce= 50ms, n=   100000 | total=  212.62ms | p50= 0.002 p95= 0.003 p99= 0.004
debounce= 50ms, n=  1000000 | total= 2057.00ms | p50= 0.020 p95= 0.024 p99= 0.032
debounce=100ms, n=    10000 | total=   20.86ms | p50= 0.002 p95= 0.003 p99= 0.005
debounce=100ms, n=   100000 | total=  206.62ms | p50= 0.002 p95= 0.003 p99= 0.004
debounce=100ms, n=  1000000 | total= 2058.37ms | p50= 0.020 p95= 0.024 p99= 0.034
debounce=200ms, n=    10000 | total=   20.68ms | p50= 0.002 p95= 0.003 p99= 0.004
debounce=200ms, n=   100000 | total=  208.51ms | p50= 0.002 p95= 0.003 p99= 0.004
debounce=200ms, n=  1000000 | total= 2234.77ms | p50= 0.020 p95= 0.025 p99= 0.060
```

## Interpretation Guide

- 10k/100k: No significant differences in total execution/percentiles across three debounce settings (50/100/200ms).
- 1M: At 200ms, total/p99 appear relatively high (e.g., p99=0.060ms). 50ms/100ms are more stable.
- Recommendation: Start with 50ms or 100ms and adjust according to your workload.

## Notes

- The Benchmarks target is for roughly checking the effectiveness of snapshot debounce/hot-path non-blocking design. In actual apps, numbers may vary based on usage patterns/device/build options, so collect multiple times via CSV and observe average/standard deviation together.
- Snapshot debounce can be adjusted between 50~1000ms via `UnifiedDI.configureOptimization(debounceMs:)`.

---

📖 **Documentation**: [한국어](../ko.lproj/Benchmarks) | [English](Benchmarks)