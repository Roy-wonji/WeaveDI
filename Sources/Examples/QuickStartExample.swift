//
//  BasicExample.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation

/// 기본 사용 예제
public enum BasicExample {

    /// 간단한 사용법 예제
    public static func example() async {
        // 1. 부트스트랩
        await DependencyContainer.bootstrap { container in
            container.register(String.self) { "Hello, World!" }
        }

        // 2. 사용
        let message = DependencyContainer.live.resolve(String.self)
        print(message ?? "No message")
    }
}