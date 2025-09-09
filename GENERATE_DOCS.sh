#!/usr/bin/env bash
# xcodebuild 기반 DocC 생성 스크립트 (워크스페이스/프로젝트 자동 탐지 + Swift Package 폴백)
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# 설정(환경변수로 오버라이드 가능)
# ──────────────────────────────────────────────────────────────
OUTPUT_PATH="${OUTPUT_PATH:-./docs}"               # 최종 산출물 경로
SCHEME_NAME="${SCHEME_NAME:-DiContainer}"          # 문서화할 스킴
CONFIGURATION="${CONFIGURATION:-Debug}"            # Debug / Release
DESTINATION="${DESTINATION:-generic/platform=iOS}" # macOS면 generic/platform=macOS
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/docbuild}"

# GitHub Pages 유형:
#  - 사용자 페이지(username.github.io): IS_USER_SITE=true → --hosting-base-path 미사용
#  - 프로젝트 페이지(repo): IS_USER_SITE=false, HOSTING_BASE_PATH=저장소명(대/소문자 동일)
IS_USER_SITE="${IS_USER_SITE:-true}"
HOSTING_BASE_PATH="${HOSTING_BASE_PATH:-}"

# 명시적으로 경로 지정 가능(없으면 자동 탐지 / 패키지 폴백)
WORKSPACE_PATH="${WORKSPACE_PATH:-}"
PROJECT_PATH="${PROJECT_PATH:-}"
PACKAGE_PATH="${PACKAGE_PATH:-.}"

# ⚠️ 반드시 미리 초기화해 unbound variable 방지
declare -a XCODE_ARGS=()

# ──────────────────────────────────────────────────────────────
# 워크스페이스 / 프로젝트 자동 탐지 (없으면 Swift Package로 폴백)
# ──────────────────────────────────────────────────────────────
shopt -s nullglob
if [[ -n "$WORKSPACE_PATH" && -f "$WORKSPACE_PATH" ]]; then
  XCODE_ARGS=( -workspace "$WORKSPACE_PATH" )
else
  ws=( ./*.xcworkspace )
  if (( ${#ws[@]} )); then
    XCODE_ARGS=( -workspace "${ws[0]}" )
  else
    if [[ -n "$PROJECT_PATH" && -f "$PROJECT_PATH" ]]; then
      XCODE_ARGS=( -project "$PROJECT_PATH" )
    else
      proj=( ./*.xcodeproj )
      if (( ${#proj[@]} )); then
        XCODE_ARGS=( -project "${proj[0]}" )
      else
        echo "ℹ️  .xcworkspace/.xcodeproj 미발견 → Swift Package로 빌드합니다 (-package-path ${PACKAGE_PATH})"
        XCODE_ARGS=()
      fi
    fi
  fi
fi
shopt -u nullglob

# ──────────────────────────────────────────────────────────────
# 1) Xcode DocC 아카이브 생성
# ──────────────────────────────────────────────────────────────
echo "▶︎ xcodebuild docbuild"
set -x
xcodebuild docbuild \
  "${XCODE_ARGS[@]}" \
  -scheme "$SCHEME_NAME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"
set +x

# 생성된 .doccarchive 경로 탐색 (스킴 우선, 없으면 아무거나)
DOCCARCHIVE_PATH="$(/usr/bin/find "$DERIVED_DATA_PATH" -type d -name "${SCHEME_NAME}.doccarchive" | head -n 1)"
if [[ -z "$DOCCARCHIVE_PATH" ]]; then
  DOCCARCHIVE_PATH="$(/usr/bin/find "$DERIVED_DATA_PATH" -type d -name '*.doccarchive' | head -n 1)"
fi
if [[ -z "$DOCCARCHIVE_PATH" ]]; then
  echo "❌ .doccarchive 를 찾지 못했습니다. (scheme: ${SCHEME_NAME})"
  exit 1
fi
echo "✓ Found doccarchive: ${DOCCARCHIVE_PATH}"

# ──────────────────────────────────────────────────────────────
# 2) 정적 호스팅 변환 (사용자/프로젝트 페이지 대응)
# ──────────────────────────────────────────────────────────────
declare -a HOSTING_FLAG=()
if [[ "$IS_USER_SITE" != "true" && -n "$HOSTING_BASE_PATH" ]]; then
  HOSTING_FLAG=( --hosting-base-path "$HOSTING_BASE_PATH" )
fi

/usr/bin/xcrun docc process-archive \
  transform-for-static-hosting "${DOCCARCHIVE_PATH}" \
  --output-path "${OUTPUT_PATH}" \
  "${HOSTING_FLAG[@]}"

# GitHub Pages에서 DocC 리소스 차단 방지
touch "${OUTPUT_PATH}/.nojekyll"

# 문서 루트 경로(/documentation/<모듈>) 계산
MODULE_SLUG="$(basename "${DOCCARCHIVE_PATH}" .doccarchive | tr '[:upper:]' '[:lower:]')"
DOC_ROOT="documentation/${MODULE_SLUG}"

# ──────────────────────────────────────────────────────────────
# 3) /docs → /docs/documentation/<module> 리다이렉트
# ──────────────────────────────────────────────────────────────
cat > "${OUTPUT_PATH}/index.html" <<EOF
<!doctype html>
<meta charset="utf-8">
<script>
  window.location.href = "./${DOC_ROOT}";
</script>
<noscript>
  <meta http-equiv="refresh" content="0; url=./${DOC_ROOT}">
</noscript>
EOF

echo "✅ DocC 문서가 '${OUTPUT_PATH}/${DOC_ROOT}' 에 생성되었습니다."
if [[ "$IS_USER_SITE" != "true" && -n "$HOSTING_BASE_PATH" ]]; then
  echo "   Hosting base path: /${HOSTING_BASE_PATH} (프로젝트 페이지)"
else
  echo "   Hosting base path: / (사용자 페이지)"
fi
