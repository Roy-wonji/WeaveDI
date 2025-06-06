#!/usr/bin/env bash
set -e

# ──────────────────────────────────────────────────────────────
# 사전 정의 (Definition)
# ──────────────────────────────────────────────────────────────

# Docs가 생성될 최종 경로 (main 브랜치의 /docs)
OUTPUT_PATH="./docs"

# 문서를 생성할 SPM 타겟 이름
TARGET_NAME="DiContainer"

# 정적 호스팅 시 URL 경로의 base path (예: roy-wonji.github.io/LogMacro/…)
HOSTING_BASE_PATH="DiContainer"

# (만약 xcodebuild으로 DocC 아카이브를 만들고 싶다면 아래 변수를 사용하세요)
#BUILD_DESTINATION="generic/platform=iOS"
#BUILD_PATH="/tmp/docbuild"
#DOCCARCHIVE_PATH="${BUILD_PATH}/Build/Products/Debug-iphoneos/${TARGET_NAME}.doccarchive"


# ──────────────────────────────────────────────────────────────
# SwiftPM DocC 플러그인 방식
# ──────────────────────────────────────────────────────────────

swift package --allow-writing-to-directory "${OUTPUT_PATH}" \
    generate-documentation \
      --target "${TARGET_NAME}" \
      --disable-indexing \
      --output-path "${OUTPUT_PATH}" \
      --transform-for-static-hosting \
      --hosting-base-path "${HOSTING_BASE_PATH}"


# ──────────────────────────────────────────────────────────────
# Xcode 'xcodebuild docbuild' 방식 (SwiftPM이 아닌 .xcodeproj/.xcworkspace가 있을 때)
# ──────────────────────────────────────────────────────────────

# 아래 블록을 활성화하려면 주석(#)을 제거하고,
# 반드시 Xcode 프로젝트 안에 'LogMacro' 스킴이 정의되어 있어야 합니다.

#: '
#xcodebuild docbuild \
#  -scheme "${TARGET_NAME}" \
#  -derivedDataPath "${BUILD_PATH}" \
#  -destination "${BUILD_DESTINATION}"
#
#$(xcrun --find docc) process-archive \
#  transform-for-static-hosting "${DOCCARCHIVE_PATH}" \
#  --hosting-base-path "${HOSTING_BASE_PATH}" \
#  --output-path "${OUTPUT_PATH}"
#'


# ──────────────────────────────────────────────────────────────
# (선택) 최상위 /docs/index.html 에 리다이렉트 스크립트를 추가
# ──────────────────────────────────────────────────────────────

# 만약 GitHub Pages에서 `main` 브랜치의 `/docs` 폴더를 그대로 호스팅하도록 설정했다면,
# 최상위 URL 접속 시 자동으로 `/documentation/logmacro` 로 이동하게 하기 위해
# 아래 파일을 생성하실 수 있습니다.

cat > "${OUTPUT_PATH}/index.html" << 'EOF'
<script>
  // 브라우저가 /docs/ 에서 열릴 때
  // 로그메크로 패키지 문서 루트(/documentation/logmacro)로 리다이렉트
  window.location.href += "/documentation/dicontainer"
</script>
EOF

echo "✅ DocC 문서가 '${OUTPUT_PATH}/documentation/dicontainer' 에 생성되었으며,"
echo "   '${OUTPUT_PATH}/index.html' 에 리다이렉트 스크립트를 추가했습니다."

