#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# 설정 (환경변수로 오버라이드 가능)
# ──────────────────────────────────────────────────────────────
OUTPUT_PATH="${OUTPUT_PATH:-./docs}"          # 최종 산출물 폴더
TARGET_NAME="${TARGET_NAME:-DiContainer}"     # SPM 타깃(모듈) 이름

# 프로젝트 페이지(일반 저장소)면 저장소 이름(대/소문자 그대로)
# 사용자 페이지(username.github.io 저장소)면 빈 값 또는 아래 IS_USER_SITE=true 설정
HOSTING_BASE_PATH="${HOSTING_BASE_PATH:-DiContainer}"

# 사용자 페이지 여부 (true/false)
IS_USER_SITE="${IS_USER_SITE:-false}"

# DocC 문서 루트(/documentation/<모듈소문자>)
MODULE_SLUG="$(echo "$TARGET_NAME" | tr '[:upper:]' '[:lower:]')"
DOC_ROOT="documentation/${MODULE_SLUG}"

# ──────────────────────────────────────────────────────────────
# SwiftPM DocC 플러그인 방식
# ──────────────────────────────────────────────────────────────

# ✅ 항상 배열을 초기화하여 unbound variable 방지
BASE_PATH_ARGS=()
# 사용자 페이지가 아니고, base path가 설정된 경우에만 옵션 추가
if [[ "$IS_USER_SITE" != "true" && -n "$HOSTING_BASE_PATH" ]]; then
  BASE_PATH_ARGS=( --hosting-base-path "$HOSTING_BASE_PATH" )
fi

# DocC 정적 사이트 생성
swift package --allow-writing-to-directory "$OUTPUT_PATH" \
  generate-documentation \
  --target "$TARGET_NAME" \
  --disable-indexing \
  --output-path "$OUTPUT_PATH" \
  --transform-for-static-hosting \
  "${BASE_PATH_ARGS[@]}"

# GitHub Pages에서 DocC 리소스가 차단되지 않도록 .nojekyll 생성 (필수)
touch "$OUTPUT_PATH/.nojekyll"

# ──────────────────────────────────────────────────────────────
# (선택) 루트 리다이렉트 index.html
# ──────────────────────────────────────────────────────────────
cat > "$OUTPUT_PATH/index.html" <<EOF
<!doctype html>
<meta charset="utf-8">
<script>
  // /docs/ → /docs/documentation/${MODULE_SLUG}
  window.location.href = "./${DOC_ROOT}";
</script>
<noscript>
  <meta http-equiv="refresh" content="0; url=./${DOC_ROOT}">
</noscript>
EOF

echo "✅ DocC generated at: ${OUTPUT_PATH}/${DOC_ROOT}"
if [[ "$IS_USER_SITE" != "true" && -n "$HOSTING_BASE_PATH" ]]; then
  echo "   Hosting base path: /${HOSTING_BASE_PATH}"
else
  echo "   Hosting base path: /"
fi
