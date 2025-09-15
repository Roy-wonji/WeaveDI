#!/usr/bin/env python3
"""
DiContainer print() -> logMacro 자동 변환 스크립트
"""

import os
import re
import sys

def convert_file_to_logmacro(file_path):
    """파일의 print문을 logMacro로 변환"""

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # 1. import 추가 (Foundation 다음에)
    if 'import LogMacro' not in content:
        content = re.sub(
            r'(import Foundation\n)',
            r'\1import LogMacro\n',
            content
        )

    # 2. print문 변환 패턴들
    conversions = [
        # print("✅ 성공 메시지") -> #logInfo("✅ 성공 메시지")
        (r'print\("✅([^"]*?)"\)', r'#logInfo("✅\1")'),

        # print("🎉 완료 메시지") -> #logInfo("🎉 완료 메시지")
        (r'print\("🎉([^"]*?)"\)', r'#logInfo("🎉\1")'),

        # print("📊 정보 메시지") -> #logInfo("📊 정보 메시지")
        (r'print\("📊([^"]*?)"\)', r'#logInfo("📊\1")'),

        # print("🔍 검사 메시지") -> #logInfo("🔍 정보 메시지")
        (r'print\("🔍([^"]*?)"\)', r'#logInfo("🔍\1")'),

        # print("❌ 에러 메시지") -> #logError("❌ 에러 메시지")
        (r'print\("❌([^"]*?)"\)', r'#logError("❌\1")'),

        # print("⚠️ 경고 메시지") -> #logWarning("⚠️ 경고 메시지")
        (r'print\("⚠️([^"]*?)"\)', r'#logWarning("⚠️\1")'),

        # print("🚨 에러 메시지") -> #logError("🚨 에러 메시지")
        (r'print\("🚨([^"]*?)"\)', r'#logError("🚨\1")'),

        # print("🎨 시작 메시지") -> #logInfo("🎨 시작 메시지")
        (r'print\("🎨([^"]*?)"\)', r'#logInfo("🎨\1")'),

        # print("🔄 진행 메시지") -> #logInfo("🔄 진행 메시지")
        (r'print\("🔄([^"]*?)"\)', r'#logInfo("🔄\1")'),

        # print("💡 팁 메시지") -> #logInfo("💡 팁 메시지")
        (r'print\("💡([^"]*?)"\)', r'#logInfo("💡\1")'),

        # 일반적인 정보성 print -> #logInfo
        (r'print\("([^"]*?)완료([^"]*?)"\)', r'#logInfo("\1완료\2")'),
        (r'print\("([^"]*?)시작([^"]*?)"\)', r'#logInfo("\1시작\2")'),
        (r'print\("([^"]*?)생성([^"]*?)"\)', r'#logInfo("\1생성\2")'),

        # 멀티라인 문자열 처리
        (r'print\("""', r'#logInfo("""'),

        # 나머지 일반 print -> #logDebug (개발용)
        (r'print\("([^"]*?)"\)', r'#logDebug("\1")'),

        # 변수가 포함된 print -> #logDebug
        (r'print\(([^)]+?)\)', r'#logDebug(\1)'),
    ]

    # 변환 적용
    for pattern, replacement in conversions:
        content = re.sub(pattern, replacement, content)

    # 변경사항이 있으면 파일 저장
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True

    return False

def main():
    """메인 함수"""
    sources_dir = "/Users/suhwonji/Desktop/SideProject/DiContainer/Sources"

    if not os.path.exists(sources_dir):
        print(f"❌ 디렉토리를 찾을 수 없습니다: {sources_dir}")
        return

    print("🔄 logMacro 변환 시작...")

    converted_files = []

    # 모든 Swift 파일 찾기
    for root, dirs, files in os.walk(sources_dir):
        for file in files:
            if file.endswith('.swift'):
                file_path = os.path.join(root, file)

                # 변환 실행
                if convert_file_to_logmacro(file_path):
                    converted_files.append(file_path)
                    print(f"✅ 변환됨: {file}")

    print(f"\n🎉 변환 완료!")
    print(f"📄 총 {len(converted_files)}개 파일이 변환되었습니다.")

    if converted_files:
        print("\n변환된 파일 목록:")
        for file_path in converted_files:
            file_name = os.path.basename(file_path)
            print(f"  • {file_name}")

if __name__ == "__main__":
    main()