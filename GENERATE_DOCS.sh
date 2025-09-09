#!/usr/bin/env bash
# xcodebuild 기반 DocC 생성 스크립트 (워크스페이스/프로젝트 자동 탐지 + SPM일 때 임시 워크스페이스 생성)
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# 설정(환경변수로 오버라이드 가능)
# ──────────────────────────────────────────────────────────────
OUTPUT_PATH="${OUTPUT_PATH:-./docs}"               # 최종 산출물 경로
SCHEME_NAME="${SCHEME_NAME:-DiContainer}"          # 문서화할 스킴(= 패키지 제품명과 동일해야 함)
CONFIGURATION="${CONFIGURATION:-Debug}"            # Debug / Release
DESTINATION="${DESTINATION:-generic/platform=iOS}" # macOS면 generic/platform=macOS
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/docbuild}"

IS_USER_SITE="${IS_USER_SITE:-true}"
HOSTING_BASE_PATH="${HOSTING_BASE_PATH:-}"

WORKSPACE_PATH="${WORKSPACE_PATH:-}"
PROJECT_PATH="${PROJECT_PATH:-}"
PACKAGE_PATH="${PACKAGE_PATH:-.}"

# 배열 초기화
declare -a XCODE_ARGS=()

# ──────────────────────────────────────────────────────────────
# 워크스페이스 / 프로젝트 자동 탐지 (없으면 SPM용 임시 워크스페이스 생성)
# ──────────────────────────────────────────────────────────────
shopt -s nullglob
if [[ -n "$WORKSPACE_PATH" && -d "$WORKSPACE_PATH" ]]; then
  XCODE_ARGS=( -workspace "$WORKSPACE_PATH" )
else
  ws=( ./*.xcworkspace )
  if (( ${#ws[@]} )); then
    XCODE_ARGS=( -workspace "${ws[0]}" )
  else
    if [[ -n "$PROJECT_PATH" && -d "$PROJECT_PATH" ]]; then
      XCODE_ARGS=( -project "$PROJECT_PATH" )
    else
      proj=( ./*.xcodeproj )
      if (( ${#proj[@]} )); then
        XCODE_ARGS=( -project "${proj[0]}" )
      else
        echo "ℹ️  .xcworkspace/.xcodeproj 미발견 → SPM을 워크스페이스에 붙여 xcodebuild로 진행합니다."
        # ✅ SPM 패키지를 포함하는 임시 워크스페이스 생성
        ABS_PACKAGE_PATH="$(cd "$PACKAGE_PATH" && pwd)"
        TEMP_WS_DIR="${DERIVED_DATA_PATH}/SPMDocs.xcworkspace"
        mkdir -p "$TEMP_WS_DIR"
        cat > "${TEMP_WS_DIR}/contents.xcworkspacedata" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version = "1.0">
   <FileRef location = "group:${ABS_PACKAGE_PATH}"/>
</Workspace>
EOF
        echo "   생성한 워크스페이스: ${TEMP_WS_DIR}"
        XCODE_ARGS=( -workspace "$TEMP_WS_DIR" )
      fi
    fi
  fi
fi
shopt -u nullglob

# ──────────────────────────────────────────────────────────────
# 1) DocC 아카이브 생성
#    SPM 패키지의 경우 swift package 명령어 사용, 아니면 xcodebuild 사용
# ──────────────────────────────────────────────────────────────
if [[ "${XCODE_ARGS[0]:-}" == "-workspace" ]] && [[ "${XCODE_ARGS[1]}" == *"SPMDocs.xcworkspace" ]]; then
  # SPM 패키지인 경우 - swift package 명령어로 직접 정적 사이트 생성
  echo "▶︎ swift package generate-documentation (정적 사이트 직접 생성)"
  
  # 임시 디렉터리에 생성 후 최종 위치로 이동
  TEMP_OUTPUT="/tmp/docbuild_temp"
  rm -rf "$TEMP_OUTPUT"
  mkdir -p "$TEMP_OUTPUT"
  
  set -x
  swift package generate-documentation \
    --target "$SCHEME_NAME" \
    --output-path "$TEMP_OUTPUT"
  set +x
  
  # 최종 위치로 이동
  rm -rf "$OUTPUT_PATH"
  mv "$TEMP_OUTPUT" "$OUTPUT_PATH"
  
  # GitHub Pages 리소스 차단 방지
  touch "${OUTPUT_PATH}/.nojekyll"
  
  # 문서 루트(/documentation/<모듈>) 계산
  MODULE_SLUG="$(echo "$SCHEME_NAME" | tr '[:upper:]' '[:lower:]')"
  DOC_ROOT="documentation/${MODULE_SLUG}"
  
  # /docs → /docs/documentation/<module> 리다이렉트
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
  exit 0
else
  # 일반 Xcode 프로젝트/워크스페이스인 경우
  echo "▶︎ xcodebuild docbuild"
  set -x
  xcodebuild docbuild \
    "${XCODE_ARGS[@]}" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH"
  set +x
  
  # 스킴명과 동일한 .doccarchive 우선 탐색, 없으면 아무거나
  DOCCARCHIVE_PATH="$(/usr/bin/find "$DERIVED_DATA_PATH" -type d -name "${SCHEME_NAME}.doccarchive" | head -n 1)"
  if [[ -z "$DOCCARCHIVE_PATH" ]]; then
    DOCCARCHIVE_PATH="$(/usr/bin/find "$DERIVED_DATA_PATH" -type d -name '*.doccarchive' | head -n 1)"
  fi
fi

if [[ -z "$DOCCARCHIVE_PATH" ]]; then
  echo "❌ .doccarchive 를 찾지 못했습니다. (scheme: ${SCHEME_NAME})"
  echo "   사용 가능한 스킴 목록:"
  if [[ "${XCODE_ARGS[0]:-}" == "-workspace" ]]; then
    xcodebuild -list "${XCODE_ARGS[@]}" || true
  elif [[ "${XCODE_ARGS[0]:-}" == "-project" ]]; then
    xcodebuild -list "${XCODE_ARGS[@]}" || true
  fi
  exit 1
fi
echo "✓ Found doccarchive: ${DOCCARCHIVE_PATH}"

# ──────────────────────────────────────────────────────────────
# 2) 정적 호스팅으로 변환
# ──────────────────────────────────────────────────────────────
declare -a HOSTING_FLAG=()
if [[ "$IS_USER_SITE" != "true" && -n "$HOSTING_BASE_PATH" ]]; then
  HOSTING_FLAG=( --hosting-base-path "$HOSTING_BASE_PATH" )
fi

/usr/bin/xcrun docc process-archive \
  transform-for-static-hosting "${DOCCARCHIVE_PATH}" \
  --output-path "${OUTPUT_PATH}" \
  "${HOSTING_FLAG[@]}"

# GitHub Pages 리소스 차단 방지
touch "${OUTPUT_PATH}/.nojekyll"

# 문서 루트(/documentation/<모듈>) 계산
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
