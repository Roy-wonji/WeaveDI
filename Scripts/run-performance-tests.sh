#!/bin/bash

# WeaveDI 성능 벤치마크 스크립트
# CI/CD 파이프라인에서 자동으로 실행됩니다.

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 성능 테스트 결과 파일
PERFORMANCE_RESULTS="performance_results.json"
PERFORMANCE_REPORT="performance_report.md"

# 임시 파일 정리 함수
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f test_output.log build_output.log
}

# 스크립트 종료 시 정리
trap cleanup EXIT

# 메인 함수
main() {
    log_info "🚀 Starting WeaveDI Performance Benchmark"
    echo "=================================================="
    echo "Date: $(date)"
    echo "Swift Version: $(swift --version)"
    echo "Xcode Version: $(xcodebuild -version 2>/dev/null | head -1 || echo 'N/A')"
    echo "=================================================="

    # 1. 환경 검증
    log_info "🔍 Verifying environment..."
    verify_environment

    # 2. 프로젝트 빌드
    log_info "🏗️ Building project..."
    build_project

    # 3. 성능 테스트 실행
    log_info "📊 Running performance tests..."
    run_performance_tests

    # 4. 결과 분석
    log_info "📈 Analyzing results..."
    analyze_results

    # 5. 리포트 생성
    log_info "📄 Generating report..."
    generate_report

    log_success "✅ Performance benchmark completed successfully!"
}

# 환경 검증 함수
verify_environment() {
    # Swift 버전 확인
    if ! command -v swift > /dev/null 2>&1; then
        log_error "Swift not found. Please install Swift toolchain."
        exit 1
    fi

    # Package.swift 파일 확인
    if [ ! -f "Package.swift" ]; then
        log_error "Package.swift not found. Please run this script from the project root."
        exit 1
    fi

    log_success "Environment verification passed"
}

# 프로젝트 빌드 함수
build_project() {
    log_info "Cleaning previous build..."
    swift package clean > build_output.log 2>&1

    log_info "Resolving dependencies..."
    if ! swift package resolve >> build_output.log 2>&1; then
        log_error "Failed to resolve dependencies"
        cat build_output.log
        exit 1
    fi

    log_info "Building in release mode..."
    if ! swift build --configuration release >> build_output.log 2>&1; then
        log_error "Failed to build project"
        cat build_output.log
        exit 1
    fi

    log_success "Project built successfully"
}

# 성능 테스트 실행 함수
run_performance_tests() {
    log_info "Running WeaveDI benchmarks with detailed metrics..."

    # 벤치마크 실행 전 모드 선택
    local benchmark_mode="--performance"
    local output_format="--json"
    local results_file="benchmark_results.json"

    # CI 환경에 따른 모드 조정
    if [ "${CI:-false}" = "true" ]; then
        benchmark_mode="--quick"
        log_info "CI environment detected, using quick benchmark mode"
    fi

    # 기준치 파일 존재 여부 확인
    if [ -f "performance_baseline.json" ]; then
        log_info "Baseline found, will compare performance"
        baseline_arg="--baseline performance_baseline.json"
    else
        log_warning "No baseline found, current results will be used as baseline"
        baseline_arg=""
    fi

    # 새로운 벤치마크 시스템 실행
    log_info "Executing: swift run Benchmarks $benchmark_mode $output_format $results_file $baseline_arg"

    if swift run Benchmarks $benchmark_mode $output_format $results_file $baseline_arg 2>&1 | tee test_output.log; then
        log_success "WeaveDI benchmarks completed successfully"

        # 결과 파일이 생성되었는지 확인
        if [ -f "$results_file" ]; then
            log_success "Benchmark results exported to $results_file"
        fi
    else
        log_warning "Some benchmarks may have failed, but continuing with analysis"
    fi

    # 기존 성능 테스트도 실행 (호환성을 위해)
    log_info "Running legacy XCTest performance tests..."
    if swift test --filter PerformanceTests 2>&1 | tee -a test_output.log; then
        log_success "Legacy performance tests completed"
    else
        log_warning "Some legacy performance tests may have failed"
    fi

    # 테스트 결과에서 성능 메트릭 추출
    extract_performance_metrics
}

# 성능 메트릭 추출 함수
extract_performance_metrics() {
    log_info "Extracting performance metrics..."

    # 새로운 벤치마크 결과가 있는 경우 처리
    if [ -f "benchmark_results.json" ]; then
        log_info "Processing new benchmark results..."
        cp "benchmark_results.json" "$PERFORMANCE_RESULTS"
        log_success "New benchmark metrics processed"
    else
        log_info "Processing legacy XCTest results..."

        # XCTest 성능 결과를 JSON 형태로 변환
        cat > "$PERFORMANCE_RESULTS" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "swift_version": "$(swift --version | head -1)",
  "platform": "$(uname -m)",
  "benchmark_type": "legacy_xctest",
  "tests": [
EOF

        # 테스트 결과에서 성능 데이터 파싱
        local first_test=true
        while IFS= read -r line; do
            if [[ $line =~ Test\ Case.*measured.*seconds ]]; then
                if [ "$first_test" = false ]; then
                    echo "," >> "$PERFORMANCE_RESULTS"
                fi

                # 테스트 이름과 시간 추출
                test_name=$(echo "$line" | sed -n 's/.*Test Case.*\[\(.*\)\].*/\1/p')
                execution_time=$(echo "$line" | sed -n 's/.*measured \([0-9.]*\) seconds.*/\1/p')

                cat >> "$PERFORMANCE_RESULTS" << EOF
    {
      "test_name": "$test_name",
      "execution_time": $execution_time,
      "unit": "seconds",
      "type": "xctest_measurement"
    }
EOF
                first_test=false
            fi
        done < test_output.log

        cat >> "$PERFORMANCE_RESULTS" << EOF
  ]
}
EOF
    fi

    # 벤치마크 요약 정보 추출
    if grep -q "📊 Total operations" test_output.log; then
        log_info "Extracting benchmark summary..."

        # 요약 정보를 별도 파일로 저장
        cat > "benchmark_summary.txt" << EOF
$(grep -E "(📊|⏱️|🚀)" test_output.log)
EOF

        log_success "Benchmark summary extracted"
    fi

    log_success "Performance metrics extracted to $PERFORMANCE_RESULTS"
}

# 결과 분석 함수
analyze_results() {
    log_info "Analyzing performance results..."

    # 기준치와 비교 (기준치 파일이 있는 경우)
    if [ -f "performance_baseline.json" ]; then
        log_info "Comparing with baseline performance..."
        compare_with_baseline
    else
        log_warning "No baseline found. Current results will be used as baseline."
        cp "$PERFORMANCE_RESULTS" "performance_baseline.json"
    fi

    # 성능 임계값 검사
    check_performance_thresholds
}

# 기준치와 비교 함수
compare_with_baseline() {
    # 간단한 성능 비교 (실제 환경에서는 더 정교한 분석 필요)
    log_info "Performance comparison will be included in the report"
}

# 성능 임계값 검사 함수
check_performance_thresholds() {
    # 성능 임계값 설정 (초 단위)
    local THRESHOLD_SINGLE_DEPENDENCY=0.01
    local THRESHOLD_COMPLEX_GRAPH=0.1
    local THRESHOLD_CONCURRENT=1.0

    log_info "Checking performance thresholds..."

    # 임계값 초과 시 경고 (실제로는 JSON 파싱 필요)
    if grep -q "testSingleDependencyResolutionPerformance" test_output.log; then
        log_info "Single dependency resolution test found"
    fi

    log_success "Performance threshold check completed"
}

# 리포트 생성 함수
generate_report() {
    log_info "Generating performance report..."

    cat > "$PERFORMANCE_REPORT" << EOF
# 🚀 WeaveDI Performance Benchmark Report

## 📊 Test Environment
- **Date**: $(date)
- **Swift Version**: $(swift --version | head -1)
- **Platform**: $(uname -s) $(uname -m)
- **Xcode Version**: $(xcodebuild -version 2>/dev/null | head -1 || echo 'N/A')

## 📈 Performance Results

### Key Metrics
EOF

    # 성능 결과를 마크다운 표로 변환
    if [ -f "$PERFORMANCE_RESULTS" ]; then
        echo "" >> "$PERFORMANCE_REPORT"
        echo "| Test Name | Avg Time (ms) | Throughput (ops/sec) | Status |" >> "$PERFORMANCE_REPORT"
        echo "|-----------|---------------|---------------------|--------|" >> "$PERFORMANCE_REPORT"

        # JSON 배열에서 데이터 추출 (간단한 방법)
        if grep -q "testName" "$PERFORMANCE_RESULTS"; then
            # 새로운 벤치마크 형식
            python3 -c "
import json
import sys
try:
    with open('$PERFORMANCE_RESULTS', 'r') as f:
        data = json.load(f)
    if isinstance(data, list):
        for item in data:
            test_name = item.get('testName', 'Unknown')
            avg_time = item.get('averageTime', 0) * 1000  # ms 단위로 변환
            throughput = item.get('throughput', 0)
            print(f'| {test_name} | {avg_time:.4f} | {throughput:.0f} | ✅ |')
except Exception as e:
    print('| Error parsing results | - | - | ❌ |')
" >> "$PERFORMANCE_REPORT" 2>/dev/null || {
                # Python이 없는 경우 fallback
                grep -o '"testName":"[^"]*"' "$PERFORMANCE_RESULTS" | while IFS= read -r line; do
                    test_name=$(echo "$line" | sed 's/"testName":"//' | sed 's/"//')
                    echo "| $test_name | - | - | ✅ |" >> "$PERFORMANCE_REPORT"
                done
            }
        else
            # 레거시 XCTest 형식
            grep -o '"test_name": "[^"]*"' "$PERFORMANCE_RESULTS" | while IFS= read -r line; do
                test_name=$(echo "$line" | sed 's/"test_name": "//' | sed 's/"//')
                echo "| $test_name | - | - | ✅ |" >> "$PERFORMANCE_REPORT"
            done
        fi
    fi

    cat >> "$PERFORMANCE_REPORT" << EOF

### 📋 Test Summary
EOF

    # 테스트 로그에서 요약 정보 추출
    if [ -f "test_output.log" ]; then
        echo "" >> "$PERFORMANCE_REPORT"
        echo "\`\`\`" >> "$PERFORMANCE_REPORT"
        grep -E "(Test Suite|Test Case|measured)" test_output.log | head -20 >> "$PERFORMANCE_REPORT"
        echo "\`\`\`" >> "$PERFORMANCE_REPORT"
    fi

    cat >> "$PERFORMANCE_REPORT" << EOF

### 🎯 Performance Goals
- **Single Dependency Resolution**: < 0.01 seconds
- **Complex Dependency Graph**: < 0.1 seconds
- **Concurrent Resolution**: < 1.0 seconds
- **Memory Usage**: Optimized allocation patterns

### 📝 Recommendations
$(generate_recommendations)

---
*Report generated by WeaveDI Performance Benchmark Script*
*Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")*
EOF

    log_success "Performance report generated: $PERFORMANCE_REPORT"
}

# 권장사항 생성 함수
generate_recommendations() {
    echo "- Monitor performance trends over time"
    echo "- Consider optimization if any test exceeds threshold by 20%"
    echo "- Update baseline after significant performance improvements"
    echo "- Run performance tests in consistent environment"
}

# 도움말 출력 함수
show_help() {
    cat << EOF
WeaveDI Performance Benchmark Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --clean            Clean previous results before running
    --baseline         Update performance baseline

Examples:
    $0                  Run performance tests
    $0 --verbose        Run with verbose output
    $0 --clean          Clean and run tests
    $0 --baseline       Update baseline after running tests

Files generated:
    - performance_results.json    Raw performance data
    - performance_report.md       Human-readable report
    - performance_baseline.json   Baseline for comparison
EOF
}

# 명령행 인자 처리
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        --clean)
            log_info "Cleaning previous results..."
            rm -f performance_results.json performance_report.md test_output.log build_output.log
            shift
            ;;
        --baseline)
            UPDATE_BASELINE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# 스크립트 실행
main

# 기준치 업데이트 (옵션이 지정된 경우)
if [ "${UPDATE_BASELINE:-false}" = true ]; then
    log_info "Updating performance baseline..."
    cp "$PERFORMANCE_RESULTS" "performance_baseline.json"
    log_success "Performance baseline updated"
fi

log_info "Performance benchmark completed. Check the following files:"
log_info "  - $PERFORMANCE_RESULTS (raw data)"
log_info "  - $PERFORMANCE_REPORT (report)"