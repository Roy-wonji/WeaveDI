//
//  DocumentationValidator.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

// MARK: - Documentation Link Validator

/// 문서 링크 유효성 검사기
public final class DocumentationValidator: @unchecked Sendable {

    // MARK: - Shared Instance

    public static let shared = DocumentationValidator()

    // MARK: - Properties

    private let fileManager = FileManager.default

    // MARK: - Initialization

    private init() {}

    // MARK: - Validation API

    /// 모든 문서 링크 유효성 검사
    public func validateAllDocumentationLinks(
        in projectPath: String = "/Users/suhwonji/Desktop/SideProject/DiContainer"
    ) -> DocumentationValidationResult {
        #logInfo("🔍 문서 링크 유효성 검사 시작...")

        let docsPath = "\(projectPath)/Sources/DiContainer.docc"
        var brokenLinks: [BrokenLink] = []
        var validLinks: [String] = []
        var missingFiles: [String] = []

        // 모든 .md 파일 찾기
        let mdFiles = findMarkdownFiles(in: docsPath)

        for filePath in mdFiles {
            let result = validateDocumentationFile(at: filePath, docsRoot: docsPath)
            brokenLinks.append(contentsOf: result.brokenLinks)
            validLinks.append(contentsOf: result.validLinks)
        }

        // 누락된 파일들 찾기
        missingFiles = findMissingDocumentationFiles(docsPath: docsPath, brokenLinks: brokenLinks)

        let result = DocumentationValidationResult(
            totalFiles: mdFiles.count,
            brokenLinks: brokenLinks,
            validLinks: validLinks,
            missingFiles: missingFiles
        )

        printValidationSummary(result)
        return result
    }

    /// 깨진 링크 자동 수정
    public func autoFixBrokenLinks(
        in projectPath: String = "/Users/suhwonji/Desktop/SideProject/DiContainer",
        dryRun: Bool = true
    ) throws {
        #logDebug("🔧 문서 링크 자동 수정 \(dryRun ? "(Dry Run)" : "")...")

        let validationResult = validateAllDocumentationLinks(in: projectPath)
        let fixes = generateAutoFixes(for: validationResult.brokenLinks)

        for fix in fixes {
            #logDebug("\n📝 \(fix.filePath):")
            #logDebug("   변경: \(fix.oldLink) → \(fix.newLink)")

            if !dryRun {
                try applyLinkFix(fix)
            }
        }

        #logDebug("\n✅ 자동 수정 \(dryRun ? "계획" : "완료"): \(fixes.count)개 링크")
    }

    /// 누락된 문서 파일 생성
    public func createMissingDocumentationFiles(
        in projectPath: String = "/Users/suhwonji/Desktop/SideProject/DiContainer"
    ) throws {
        #logInfo("📄 누락된 문서 파일 생성 중...")

        let validationResult = validateAllDocumentationLinks(in: projectPath)
        let docsPath = "\(projectPath)/Sources/DiContainer.docc"

        for missingFile in validationResult.missingFiles {
            let fullPath = "\(docsPath)/\(missingFile)"
            let content = generateDocumentationTemplate(for: missingFile)

            // 디렉토리 생성
            let directory = URL(fileURLWithPath: fullPath).deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            // 파일 생성
            try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
            #logInfo("📄 생성: \(missingFile)")
        }
    }

    // MARK: - Private Helpers

    private func findMarkdownFiles(in docsPath: String) -> [String] {
        var mdFiles: [String] = []

        guard let enumerator = fileManager.enumerator(atPath: docsPath) else {
            return []
        }

        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".md") {
                mdFiles.append("\(docsPath)/\(file)")
            }
        }

        return mdFiles
    }

    private func validateDocumentationFile(
        at filePath: String,
        docsRoot: String
    ) -> FileValidationResult {
        var brokenLinks: [BrokenLink] = []
        var validLinks: [String] = []

        guard let content = try? String(contentsOfFile: filePath) else {
            return FileValidationResult(brokenLinks: [], validLinks: [])
        }

        // <doc:파일명> 패턴 찾기
        let docLinkPattern = #"<doc:([^>]+)>"#
        let regex = try! NSRegularExpression(pattern: docLinkPattern)
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for match in matches {
            guard let range = Range(match.range(at: 1), in: content) else { continue }
            let linkTarget = String(content[range])

            // 링크 대상 파일 존재 확인
            let possiblePaths = generatePossiblePaths(for: linkTarget, docsRoot: docsRoot)
            let fileExists = possiblePaths.contains { fileManager.fileExists(atPath: $0) }

            if fileExists {
                validLinks.append(linkTarget)
            } else {
                brokenLinks.append(BrokenLink(
                    filePath: filePath,
                    linkText: "<doc:\(linkTarget)>",
                    target: linkTarget,
                    possiblePaths: possiblePaths
                ))
            }
        }

        return FileValidationResult(brokenLinks: brokenLinks, validLinks: validLinks)
    }

    private func generatePossiblePaths(for linkTarget: String, docsRoot: String) -> [String] {
        let variations = [
            "\(docsRoot)/ko.lproj/\(linkTarget).md",
            "\(docsRoot)/en.lproj/\(linkTarget).md",
            "\(docsRoot)/\(linkTarget).md",
            // 영어 파일명 변환
            "\(docsRoot)/ko.lproj/\(convertToEnglish(linkTarget)).md",
            "\(docsRoot)/en.lproj/\(convertToEnglish(linkTarget)).md"
        ]

        return variations
    }

    private func convertToEnglish(_ koreanFileName: String) -> String {
        let mapping: [String: String] = [
            "빠른시작": "QuickStart",
            "코어API": "CoreAPIs",
            "모듈시스템": "ModuleSystem",
            "프로퍼티래퍼": "PropertyWrappers",
            "액터홉최적화": "ActorHopOptimization",
            "액터홉": "ActorHop",
            "플러그인시스템": "PluginSystem",
            "자동해결": "AutoResolution",
            "컨테이너사용": "ContainerUsage",
            "컨테이너성능": "ContainerPerformance",
            "의존성키패턴": "DependencyKeyPatterns",
            "대량등록DSL": "BulkRegistrationDSL",
            "모듈팩토리": "ModuleFactory",
            "통합DI": "UnifiedDI",
            "실용가이드": "PracticalGuide",
            "부트스트랩시스템": "BootstrapSystem",
            "앱DI통합": "AppDIIntegration",
            "레거시API": "LegacyAPIs"
        ]

        return mapping[koreanFileName] ?? koreanFileName
    }

    private func findMissingDocumentationFiles(
        docsPath: String,
        brokenLinks: [BrokenLink]
    ) -> [String] {
        var missingFiles: Set<String> = []

        for link in brokenLinks {
            // 한국어 파일이 있는지 확인
            let koreanPath = "ko.lproj/\(link.target).md"
            let koreanFullPath = "\(docsPath)/\(koreanPath)"

            if fileManager.fileExists(atPath: koreanFullPath) {
                // 한국어 파일은 있지만 영어 파일이 없는 경우
                let englishPath = "en.lproj/\(convertToEnglish(link.target)).md"
                missingFiles.insert(englishPath)
            } else {
                // 두 언어 모두 없는 경우
                missingFiles.insert("ko.lproj/\(link.target).md")
                missingFiles.insert("en.lproj/\(convertToEnglish(link.target)).md")
            }
        }

        return Array(missingFiles)
    }

    private func generateAutoFixes(for brokenLinks: [BrokenLink]) -> [LinkFix] {
        var fixes: [LinkFix] = []

        for link in brokenLinks {
            // 가능한 수정 방법들
            let englishTarget = convertToEnglish(link.target)

            // 1. 영어명으로 변경
            if englishTarget != link.target {
                fixes.append(LinkFix(
                    filePath: link.filePath,
                    oldLink: "<doc:\(link.target)>",
                    newLink: "<doc:\(englishTarget)>",
                    reason: "영어 파일명으로 변경"
                ))
            }

            // 2. ko.lproj 경로 명시
            fixes.append(LinkFix(
                filePath: link.filePath,
                oldLink: "<doc:\(link.target)>",
                newLink: "<doc:ko.lproj/\(link.target)>",
                reason: "한국어 경로 명시"
            ))
        }

        return fixes
    }

    private func applyLinkFix(_ fix: LinkFix) throws {
        let content = try String(contentsOfFile: fix.filePath)
        let newContent = content.replacingOccurrences(of: fix.oldLink, with: fix.newLink)

        try newContent.write(toFile: fix.filePath, atomically: true, encoding: .utf8)
    }

    private func generateDocumentationTemplate(for fileName: String) -> String {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let englishName = convertToEnglish(baseName)

        return """
        # \(englishName)

        > **Note**: This documentation file was auto-generated. Please update with actual content.

        ## Overview

        This document covers \(englishName.lowercased()) functionality in DiContainer.

        ## Topics

        ### Getting Started

        Basic usage and examples.

        ### Advanced Usage

        Advanced patterns and configurations.

        ## See Also

        - <doc:DiContainer>
        - <doc:QuickStart>
        """
    }

    private func printValidationSummary(_ result: DocumentationValidationResult) {
        #logDebug("\n📊 문서 링크 검사 결과:")
        #logDebug("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        #logDebug("📄 검사 파일: \(result.totalFiles)개")
        #logInfo("✅ 유효 링크: \(result.validLinks.count)개")
        #logError("❌ 깨진 링크: \(result.brokenLinks.count)개")
        #logDebug("📄 누락 파일: \(result.missingFiles.count)개")

        if !result.brokenLinks.isEmpty {
            #logDebug("\n🔗 깨진 링크 목록:")
            for link in result.brokenLinks.prefix(10) {
                let fileName = URL(fileURLWithPath: link.filePath).lastPathComponent
                #logDebug("   • \(fileName): \(link.linkText)")
            }
            if result.brokenLinks.count > 10 {
                #logDebug("   ... 그 외 \(result.brokenLinks.count - 10)개")
            }
        }

        if !result.missingFiles.isEmpty {
            #logDebug("\n📄 누락된 파일:")
            for file in result.missingFiles.prefix(5) {
                #logDebug("   • \(file)")
            }
            if result.missingFiles.count > 5 {
                #logDebug("   ... 그 외 \(result.missingFiles.count - 5)개")
            }
        }

        #logDebug("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}

// MARK: - Data Structures

/// 문서 유효성 검사 결과
public struct DocumentationValidationResult {
    public let totalFiles: Int
    public let brokenLinks: [BrokenLink]
    public let validLinks: [String]
    public let missingFiles: [String]

    public var isValid: Bool {
        return brokenLinks.isEmpty && missingFiles.isEmpty
    }
}

/// 파일별 검사 결과
public struct FileValidationResult {
    public let brokenLinks: [BrokenLink]
    public let validLinks: [String]
}

/// 깨진 링크 정보
public struct BrokenLink {
    public let filePath: String
    public let linkText: String
    public let target: String
    public let possiblePaths: [String]
}

/// 링크 수정 정보
public struct LinkFix {
    public let filePath: String
    public let oldLink: String
    public let newLink: String
    public let reason: String
}

// MARK: - CLI Integration

public extension DocumentationValidator {

    /// 명령줄에서 사용할 수 있는 빠른 검사
    static func quickValidate(
        projectPath: String? = nil,
        autoFix: Bool = false
    ) throws {
        let path = projectPath ?? "/Users/suhwonji/Desktop/SideProject/DiContainer"

        let validator = DocumentationValidator.shared
        let result = validator.validateAllDocumentationLinks(in: path)

        if !result.isValid && autoFix {
            #logInfo("\n🔧 자동 수정 시작...")
            try validator.autoFixBrokenLinks(in: path, dryRun: false)
            try validator.createMissingDocumentationFiles(in: path)
        }

        // 수정 후 재검사
        if autoFix {
            #logDebug("\n🔍 재검사 중...")
            let afterResult = validator.validateAllDocumentationLinks(in: path)
            if afterResult.isValid {
                #logInfo("🎉 모든 문서 링크가 수정되었습니다!")
            }
        }
    }
}