// docs/.vitepress/config.ts
import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'WeaveDI',
  description: 'Modern Dependency Injection Framework for Swift',
  base: '/WeaveDI/',

  // Default locale (English)
  lang: 'en',

  // ✅ Dead link 검사: 로컬에선 ON, CI에선 OFF (VP_IGNORE_DEAD_LINKS=1)
  ignoreDeadLinks: process.env.VP_IGNORE_DEAD_LINKS === '1',
  // 또는 특정 경로만 임시 무시하고 싶다면:
  // ignoreDeadLinks: [
  //   /^https?:\/\//,                 // 외부 링크 무시
  //   /#.+$/,                         // 앵커만 있는 내부 링크 무시
  //   /^\/(ko\/)?guide\/(module-factory|runtime-optimization)(\.html)?$/ // 작성 예정 문서
  // ],

  locales: {
    root: {
      label: 'English',
      lang: 'en',
      title: 'WeaveDI',
      description: 'Modern Dependency Injection Framework for Swift',
      themeConfig: {
        nav: [
          { text: 'Home', link: '/' },
          { text: 'Guide', link: '/guide/quickStart' },
          { text: 'Tutorial', link: '/tutorial/' },
          { text: 'API Reference', link: '/api/coreApis' },
          { text: 'GitHub', link: 'https://github.com/Roy-wonji/WeaveDI' }
        ],
        sidebar: {
          '/guide/': [
            {
              text: 'Getting Started',
              collapsed: false,
              items: [
                { text: 'Quick Start', link: '/guide/quickStart' },
                { text: 'Bootstrap', link: '/guide/bootstrap' },
                { text: 'Property Wrappers', link: '/guide/propertyWrappers' }
              ]
            },
            {
              text: 'Core Concepts',
              collapsed: true,
              items: [
                { text: '@Injected', link: '/guide/injected' },
                { text: 'Unified DI', link: '/guide/unifiedDi' },
                { text: 'Container Usage', link: '/guide/containerUsage' },
                { text: 'Scopes', link: '/guide/scopes' },
                { text: 'AppDI Simplification', link: '/guide/appDiSimplification' }
              ]
            },
            {
              text: 'Advanced',
              collapsed: true,
              items: [
                { text: 'Module System', link: '/guide/moduleSystem' },
                { text: 'Module Factory', link: '/guide/moduleFactory' },
                { text: 'Auto DI Optimizer', link: '/guide/autoDiOptimizer' },
                { text: 'Runtime Optimization', link: '/guide/runtimeOptimization' },
                { text: 'DI Actor', link: '/guide/diActor' }
              ]
            },
            {
              text: 'Integration',
              collapsed: true,
              items: [
                { text: 'SwiftUI Integration', link: '/guide/swiftuiIntegration' },
                { text: 'App DI Integration', link: '/guide/appDiIntegration' },
                { text: 'TCA Integration', link: '/guide/tcaIntegration' },
                { text: 'Needle Style DI', link: '/guide/needleStyleDi' },
                { text: 'Dependency Key Patterns', link: '/guide/dependencyKeyPatterns' },
                { text: 'Bulk Registration DSL', link: '/guide/bulkRegistrationDsl' },
                { text: 'Multi-Module Projects', link: '/guide/multiModuleProjects' },
                { text: 'Practical Guide', link: '/guide/practicalGuide' },
                { text: 'Framework Comparison', link: '/guide/frameworkComparison' }
              ]
            },
            {
              text: 'Advanced Patterns',
              collapsed: true,
              items: [
                { text: 'Advanced Patterns & Best Practices', link: '/guide/advancedPatterns' },
                { text: 'Roadmap', link: '/guide/roadmap' }
              ]
            },
            {
              text: 'Migration',
              collapsed: true,
              items: [
                { text: 'Migration 2.0.0', link: '/guide/migration-2.0.0' },
                { text: 'Migration 3.0.0', link: '/guide/migration-3.0.0' },
                { text: 'Migration: @Injected', link: '/guide/migrationInjectToInjected' },
                { text: 'Migration from Other Frameworks', link: '/guide/migrationFromOtherFrameworks' }
              ]
            },
            {
              text: 'Resources',
              collapsed: true,
              items: [
                { text: 'FAQ', link: '/guide/faq' },
                { text: 'Best Practices', link: '/guide/bestPractices' },
                { text: 'Real-World Examples', link: '/guide/realWorldExamples' },
                { text: 'Troubleshooting', link: '/guide/troubleShooting' }
              ]
            }
          ],
          '/api/': [
            {
              text: 'Core APIs',
              collapsed: false,
              items: [
                { text: 'DIContainer', link: '/api/coreApis' },
                { text: 'UnifiedDI', link: '/api/unifiedDI' },
                { text: 'Bootstrap', link: '/api/bootstrap' }
              ]
            },
            {
              text: 'Property Wrappers',
              collapsed: true,
              items: [
                { text: '@Injected', link: '/api/injected' },
                { text: '@Inject (Deprecated)', link: '/api/inject' },
                { text: '@Factory', link: '/api/factory' },
                { text: '@SafeInject (Deprecated)', link: '/api/safeInject' }
              ]
            },
            {
              text: 'Advanced Features',
              collapsed: true,
              items: [
                { text: 'WeaveDI Macros', link: '/api/weaveDiMacros' },
                { text: 'Bulk Registration DSL', link: '/api/bulkRegistrationDsl' },
                { text: 'Auto DI Optimizer', link: '/api/autoDiOptimizer' },
                { text: 'DIActor', link: '/api/diActor' }
              ]
            },
            {
              text: 'Practical Guides',
              collapsed: true,
              items: [
                { text: 'Practical Patterns', link: '/api/practicalGuide' },
                { text: 'Performance Monitoring', link: '/api/performanceMonitoring' },
                { text: 'Debugging Tools', link: '/api/debuggingTools' }
              ]
            }
          ],
          '/tutorial/': [
            {
              text: 'Basic Tutorials',
              collapsed: false,
              items: [
                { text: 'Getting Started', link: '/tutorial/gettingStarted' },
                { text: 'Property Wrappers', link: '/tutorial/propertyWrappers' },
                { text: 'First App', link: '/tutorial/firstApp' }
              ]
            },
            {
              text: 'Advanced Tutorials',
              collapsed: true,
              items: [
                { text: 'Concurrency Integration', link: '/tutorial/concurrencyIntegration' },
                { text: 'Testing', link: '/tutorial/testing' },
                { text: 'Performance Optimization', link: '/tutorial/performanceOptimization' }
              ]
            }
          ]
        },
        footer: {
          message: 'Released under the MIT License.',
          copyright: 'Copyright © 2025 WeaveDI Team'
        }
      }
    },
    ko: {
      label: '한국어',
      lang: 'ko',
      title: 'WeaveDI',
      description: 'Swift를 위한 현대적 의존성 주입 프레임워크',
      themeConfig: {
        nav: [
          { text: '홈', link: '/ko/' },
          { text: '가이드', link: '/ko/guide/quickStart' },
          { text: '튜토리얼', link: '/ko/tutorial/' },
          { text: 'API 참조', link: '/ko/api/coreApis' },
          { text: 'GitHub', link: 'https://github.com/Roy-wonji/WeaveDI' }
        ],
        sidebar: {
          '/ko/guide/': [
            {
              text: '시작하기',
              collapsed: false,
              items: [
                { text: '빠른 시작', link: '/ko/guide/quickStart' },
                { text: '부트스트랩', link: '/ko/guide/bootstrap' },
                { text: '프로퍼티 래퍼', link: '/ko/guide/propertyWrappers' }
              ]
            },
            {
              text: '핵심 개념',
              collapsed: true,
              items: [
                { text: '@Injected', link: '/ko/guide/injected' },
                { text: 'Unified DI', link: '/ko/guide/unifiedDi' },
                { text: '컨테이너 사용법', link: '/ko/guide/containerUsage' },
                { text: '스코프', link: '/ko/guide/scopes' },
                { text: 'AppDI 간소화', link: '/ko/guide/appDiSimplification' }
              ]
            },
            {
              text: '고급 기능',
              collapsed: true,
              items: [
                { text: '모듈 시스템', link: '/ko/guide/moduleSystem' },
                { text: '모듈 팩토리', link: '/ko/guide/moduleFactory' },
                { text: '자동 DI 최적화', link: '/ko/guide/autoDiOptimizer' },
                { text: '런타임 최적화', link: '/ko/guide/runtimeOptimization' },
                { text: 'DI Actor', link: '/ko/guide/diActor' }
              ]
            },
            {
              text: '통합',
              collapsed: true,
              items: [
                { text: 'SwiftUI 통합', link: '/guide/swiftuiIntegration' },
                { text: '앱 DI 통합', link: '/ko/guide/appDiIntegration' },
                { text: 'TCA 통합', link: '/ko/guide/tcaIntegration' },
                { text: 'Needle 스타일 DI', link: '/ko/guide/needleStyleDi' },
                { text: '의존성 키 패턴', link: '/ko/guide/dependencyKeyPatterns' },
                { text: 'Bulk Registration DSL', link: '/ko/guide/bulkRegistrationDsl' },
                { text: '멀티 모듈 프로젝트', link: '/guide/multiModuleProjects' },
                { text: '실전 가이드', link: '/ko/guide/practicalGuide' },
                { text: '프레임워크 비교', link: '/ko/guide/frameworkComparison' }
              ]
            },
            {
              text: '고급 패턴',
              collapsed: true,
              items: [
                { text: '고급 패턴 및 모범 사례', link: '/ko/guide/advancedPatterns' },
                { text: '로드맵', link: '/ko/guide/roadmap' }
              ]
            },
            {
              text: '마이그레이션',
              collapsed: true,
              items: [
                { text: '마이그레이션 2.0.0', link: '/ko/guide/migration-2.0.0' },
                { text: '마이그레이션 3.0.0', link: '/ko/guide/migration-3.0.0' },
                { text: '마이그레이션: @Injected', link: '/ko/guide/migrationInjectToInjected' },
                { text: '다른 프레임워크에서 마이그레이션', link: '/guide/migrationFromOtherFrameworks' }
              ]
            },
            {
              text: '참고 자료',
              collapsed: true,
              items: [
                { text: 'FAQ', link: '/ko/guide/faq' },
                { text: '모범 사례', link: '/ko/guide/bestPractices' },
                { text: '실전 예제', link: '/ko/guide/realWorldExamples' },
                { text: '문제 해결', link: '/ko/ko/guide/troubleShooting' }
              ]
            }
          ],
          '/ko/api/': [
            {
              text: '핵심 API',
              collapsed: false,
              items: [
                { text: 'DIContainer', link: '/ko/api/coreApis' },
                { text: 'UnifiedDI', link: '/ko/api/unifiedDI' },
                { text: 'Bootstrap', link: '/ko/api/bootstrap' }
              ]
            },
            {
              text: 'Property Wrappers',
              collapsed: true,
              items: [
                { text: '@Injected', link: '/ko/api/injected' },
                { text: '@Inject (지원 중단)', link: '/ko/api/inject' },
                { text: '@Factory', link: '/ko/api/factory' },
                { text: '@SafeInject (지원 중단)', link: '/ko/api/safeInject' }
              ]
            },
            {
              text: '고급 기능',
              collapsed: true,
              items: [
                { text: 'WeaveDI 매크로', link: '/ko/api/weaveDiMacros' },
                { text: 'Bulk Registration DSL', link: '/ko/api/bulkRegistrationDsl' },
                { text: '자동 DI 최적화', link: '/ko/api/autoDiOptimizer' },
                { text: 'DIActor', link: '/ko/api/diActor' }
              ]
            },
            {
              text: '실전 가이드',
              collapsed: true,
              items: [
                { text: '실전 패턴', link: '/ko/api/practicalGuide' },
                { text: '성능 모니터링', link: '/ko/api/performanceMonitoring' },
                { text: '디버깅 도구', link: '/ko/api/debuggingTools' }
              ]
            }
          ],
          '/ko/tutorial/': [
            {
              text: '기초 튜토리얼',
              collapsed: false,
              items: [
                { text: '시작하기', link: '/ko/tutorial/gettingStarted' },
                { text: 'Property Wrapper', link: '/ko/tutorial/propertyWrappers' },
                { text: '첫 번째 앱', link: '/ko/tutorial/firstApp' }
              ]
            },
            {
              text: '고급 튜토리얼',
              collapsed: true,
              items: [
                { text: '동시성 통합', link: '/ko/tutorial/concurrencyIntegration' },
                { text: '테스팅', link: '/ko/tutorial/testing' },
                { text: '성능 최적화', link: '/ko/tutorial/performanceOptimization' }
              ]
            }
          ]
        },
        footer: {
          message: 'MIT 라이선스 하에 릴리스됨.',
          copyright: 'Copyright © 2025 WeaveDI Team'
        }
      }
    }
  },

  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'WeaveDI',

    search: { provider: 'local' },

    editLink: {
      pattern: 'https://github.com/Roy-wonji/WeaveDI/edit/main/docs/:path'
    },

    lastUpdated: { text: 'Last updated' },

    socialLinks: [{ icon: 'github', link: 'https://github.com/Roy-wonji/WeaveDI' }]
  },

  markdown: {
    theme: { light: 'github-light', dark: 'github-dark' },
    lineNumbers: true
  },

  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }],
    ['meta', { name: 'theme-color', content: '#646cff' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:locale', content: 'en' }],
    ['meta', { property: 'og:title', content: 'WeaveDI | Modern Dependency Injection for Swift' }],
    ['meta', { property: 'og:site_name', content: 'WeaveDI' }],
    ['meta', { property: 'og:url', content: 'https://roy-wonji.github.io/WeaveDI/' }]
  ]
})