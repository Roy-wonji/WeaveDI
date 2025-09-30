---
title: Benchmarks
lang: ko-KR
---

# 성능 벤치마크 (Benchmarks)

WeaveDI의 resolve 성능을 빠르게 점검하기 위한 간단한 벤치마크 가이드입니다. Benchmarks 실행 타깃을 통해 p50/p95/p99 및 총 소요 시간을 확인하고, 디바운스 간격에 따른 최적점을 탐색할 수 있습니다.

## 실행 방법

- 단일 조합(권장):
```bash
swift run -c release Benchmarks -- --count 100000 --debounce 100
```
- 모든 조합(기본):
```bash
swift run -c release Benchmarks
```
- 빠른 종료(첫 조합만):
```bash
swift run -c release Benchmarks -- --quick
```
- CSV 저장 및 차트(선택):
```bash
swift run -c release Benchmarks -- --count 100000 --debounce 100 --csv bench.csv
python3 Scripts/plot_bench.py --csv bench.csv --out bench_plot
```

## 샘플 결과

아래는 10k/100k/1M × 50/100/200ms 디바운스에서 측정된 샘플 출력입니다(환경에 따라 달라질 수 있습니다).

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

## 해석 가이드

- 10k/100k: 세 디바운스(50/100/200ms)에서 총 소요/퍼센타일에 큰 차이가 없습니다.
- 1M: 200ms에서 total/p99가 상대적으로 높게 나타납니다(예: p99=0.060ms). 50ms/100ms가 더 안정적입니다.
- 권장: 50ms 또는 100ms부터 시작해 워크로드에 맞춰 조정하세요.

## 참고

- Benchmarks 타깃은 스냅샷 디바운스/핫패스 비차단 설계의 효과를 대략적으로 확인하는 용도입니다. 실제 앱에서는 사용 패턴/디바이스/빌드옵션에 따라 수치가 달라질 수 있으니 CSV로 여러 차례 수집하고 평균/표준편차를 함께 보세요.
- 스냅샷 디바운스는 `UnifiedDI.configureOptimization(debounceMs:)`로 50~1000ms 사이에서 조정 가능합니다.
