import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'WeaveDI',
  description: 'Modern Dependency Injection Framework for Swift',
  base: '/WeaveDI/',

  // 다국어 설정
  locales: {
    root: {
      label: 'English',
      lang: 'en',
      title: 'WeaveDI',
      description: 'Modern Dependency Injection Framework for Swift',
      themeConfig: {
        nav: [
          { text: 'Home', link: '/' },
          { text: 'Guide', link: '/guide/quick-start' },
          { text: 'API Reference', link: '/api/core-apis' },
          { text: 'GitHub', link: 'https://github.com/Roy-wonji/WeaveDI' }
        ],
        sidebar: {
          '/guide/': [
            {
              text: 'Getting Started',
              items: [
                { text: 'Quick Start', link: '/guide/quick-start' },
                { text: 'Bootstrap', link: '/guide/bootstrap' },
                { text: 'Property Wrappers', link: '/guide/property-wrappers' }
              ]
            },
            {
              text: 'Core Concepts',
              items: [
                { text: 'Unified DI', link: '/guide/unified-di' },
                { text: 'Container Usage', link: '/guide/container-usage' },
                { text: 'Scopes', link: '/guide/scopes' }
              ]
            },
            {
              text: 'Advanced',
              items: [
                { text: 'Module System', link: '/guide/module-system' },
                { text: 'Module Factory', link: '/guide/module-factory' },
                { text: 'Auto DI Optimizer', link: '/guide/auto-di-optimizer' },
                { text: 'Runtime Optimization', link: '/guide/runtime-optimization' }
              ]
            },
            {
              text: 'Integration',
              items: [
                { text: 'App DI Integration', link: '/guide/app-di-integration' },
                { text: 'Needle Style DI', link: '/guide/needle-style-di' },
                { text: 'Dependency Key Patterns', link: '/guide/dependency-key-patterns' }
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
                { text: 'Core APIs', link: '/api/core-apis' },
                { text: 'Bulk Registration DSL', link: '/api/bulk-registration-dsl' },
                { text: 'Practical Guide', link: '/api/practical-guide' }
              ]
            }
          ]
        },
        socialLinks: [
          { icon: 'github', link: 'https://github.com/Roy-wonji/WeaveDI' }
        ],
        footer: {
          message: 'Released under the MIT License.',
          copyright: 'Copyright © 2024 WeaveDI Team'
        }
      }
    },
    ko: {
      label: '한국어',
      lang: 'ko',
      title: 'WeaveDI',
      description: 'Swift를 위한 현대적인 의존성 주입 프레임워크',
      themeConfig: {
        nav: [
          { text: '홈', link: '/ko/' },
          { text: '가이드', link: '/ko/guide/quick-start' },
          { text: 'API 참조', link: '/ko/api/core-apis' },
          { text: 'GitHub', link: 'https://github.com/Roy-wonji/WeaveDI' }
        ],
        sidebar: {
          '/ko/guide/': [
            {
              text: '시작하기',
              items: [
                { text: '빠른 시작', link: '/ko/guide/quick-start' },
                { text: '부트스트랩', link: '/ko/guide/bootstrap' },
                { text: '프로퍼티 래퍼', link: '/ko/guide/property-wrappers' }
              ]
            },
            {
              text: '핵심 개념',
              items: [
                { text: 'Unified DI', link: '/ko/guide/unified-di' },
                { text: '컨테이너 사용법', link: '/ko/guide/container-usage' },
                { text: '스코프', link: '/ko/guide/scopes' }
              ]
            },
            {
              text: '고급 기능',
              items: [
                { text: '모듈 시스템', link: '/ko/guide/module-system' },
                { text: '모듈 팩토리', link: '/ko/guide/module-factory' },
                { text: '자동 DI 최적화', link: '/ko/guide/auto-di-optimizer' },
                { text: '런타임 최적화', link: '/ko/guide/runtime-optimization' }
              ]
            },
            {
              text: '통합',
              items: [
                { text: '앱 DI 통합', link: '/ko/guide/app-di-integration' },
                { text: 'Needle 스타일 DI', link: '/ko/guide/needle-style-di' },
                { text: '의존성 키 패턴', link: '/ko/guide/dependency-key-patterns' }
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
                { text: '핵심 API', link: '/ko/api/core-apis' },
                { text: '대량 등록 DSL', link: '/ko/api/bulk-registration-dsl' },
                { text: '실전 가이드', link: '/ko/api/practical-guide' }
              ]
            }
          ]
        },
        socialLinks: [
          { icon: 'github', link: 'https://github.com/Roy-wonji/WeaveDI' }
        ],
        footer: {
          message: 'MIT 라이선스 하에 릴리스됨.',
          copyright: 'Copyright © 2024 WeaveDI Team'
        }
      }
    }
  },

  // 테마 설정
  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'WeaveDI',

    // 검색 설정
    search: {
      provider: 'local'
    },

    // 편집 링크
    editLink: {
      pattern: 'https://github.com/Roy-wonji/WeaveDI/edit/main/docs/:path'
    },

    // 마지막 업데이트
    lastUpdated: {
      text: 'Last updated'
    }
  },

  // Markdown 설정
  markdown: {
    theme: {
      light: 'github-light',
      dark: 'github-dark'
    },
    lineNumbers: true
  },

  // Head 설정
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