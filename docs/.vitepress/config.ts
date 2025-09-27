// docs/.vitepress/config.ts
import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'WeaveDI',
  description: 'Modern Dependency Injection Framework for Swift',
  base: '/WeaveDI/',

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
      description: 'Modern Dependency Injection Framework for Swift'
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
          { text: 'API 참조', link: '/ko/api/coreApis' },
          { text: 'GitHub', link: 'https://github.com/Roy-wonji/WeaveDI' }
        ],
        sidebar: {
          '/ko/guide/': [
            {
              text: '시작하기',
              items: [
                { text: '빠른 시작', link: '/ko/guide/quickStart' },
                { text: '부트스트랩', link: '/ko/guide/bootstrap' },
                { text: '프로퍼티 래퍼', link: '/ko/guide/propertyWrappers' }
              ]
            },
            {
              text: '핵심 개념',
              items: [
                { text: 'Unified DI', link: '/ko/guide/unifiedDi' },
                { text: '컨테이너 사용법', link: '/ko/guide/containerUsage' },
                { text: '스코프', link: '/ko/guide/scopes' }
              ]
            },
            {
              text: '고급 기능',
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
              items: [
                { text: '앱 DI 통합', link: '/ko/guide/appDiIntegration' },
                { text: 'Needle 스타일 DI', link: '/ko/guide/needleStyleDi' },
                { text: '의존성 키 패턴', link: '/ko/guide/dependencyKeyPatterns' },
                { text: 'Bulk Registration DSL', link: '/ko/guide/bulkRegistrationDsl' },
                { text: '실전 가이드', link: '/ko/guide/practicalGuide' }
              ]
            },
            {
              text: '마이그레이션',
              items: [
                { text: '마이그레이션 2.0.0', link: '/ko/guide/migration-2.0.0' },
                { text: '마이그레이션 3.0.0', link: '/ko/guide/migration-3.0.0' }
              ]
            }
          ],
          '/ko/api/': [
            {
              text: 'API 참조',
              items: [
                { text: '핵심 API', link: '/ko/api/coreApis' },
                { text: 'WeaveDI 매크로', link: '/ko/api/weaveDiMacros' },
                { text: 'Bulk Registration DSL', link: '/ko/api/bulkRegistrationDsl' },
                { text: '자동 DI 최적화', link: '/ko/api/autoDiOptimizer' },
                { text: '실전 가이드', link: '/ko/api/practicalGuide' }
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

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/quickStart' },
      { text: 'API Reference', link: '/api/coreApis' },
      { text: 'GitHub', link: 'https://github.com/Roy-wonji/WeaveDI' }
    ],
    sidebar: {
      '/guide/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'Quick Start', link: '/guide/quickStart' },
            { text: 'Bootstrap', link: '/guide/bootstrap' },
            { text: 'Property Wrappers', link: '/guide/propertyWrappers' }
          ]
        },
        {
          text: 'Core Concepts',
          items: [
            { text: 'Unified DI', link: '/guide/unifiedDi' },
            { text: 'Container Usage', link: '/guide/containerUsage' },
            { text: 'Scopes', link: '/guide/scopes' }
          ]
        },
        {
          text: 'Advanced',
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
          items: [
            { text: 'App DI Integration', link: '/guide/appDiIntegration' },
            { text: 'Needle Style DI', link: '/guide/needleStyleDi' },
            { text: 'Dependency Key Patterns', link: '/guide/dependencyKeyPatterns' },
            { text: 'Bulk Registration DSL', link: '/guide/bulkRegistrationDsl' },
            { text: 'Practical Guide', link: '/guide/practicalGuide' }
          ]
        },
        {
          text: 'Migration',
          items: [
            { text: 'Migration 2.0.0', link: '/guide/migration-2.0.0' },
            { text: 'Migration 3.0.0', link: '/guide/migration-3.0.0' }
          ]
        }
      ],
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Core APIs', link: '/api/coreApis' },
            { text: 'WeaveDI Macros', link: '/api/weaveDiMacros' },
            { text: 'Bulk Registration DSL', link: '/api/bulkRegistrationDsl' },
            { text: 'Auto DI Optimizer', link: '/api/autoDiOptimizer' },
            { text: 'Practical Guide', link: '/api/practicalGuide' }
          ]
        }
      ]
    },

    socialLinks: [{ icon: 'github', link: 'https://github.com/Roy-wonji/WeaveDI' }],
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2025 WeaveDI Team'
    },

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