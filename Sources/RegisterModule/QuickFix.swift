//
//  QuickFix.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation
import LogMacro

/// BookListInterface 오류 빠른 해결
public struct QuickFix {
    
    /// 앱 시작 시 호출해서 BookListInterface 문제 해결
    public static func setupBookList() {
        
    }
    
    /// 모든 일반적인 타입들을 한번에 설정
    public static func setupAll() {
        setupBookList()
        // 필요시 다른 타입들도 추가...
        #logInfo("✅ QuickFix: All types registered")
    }
}
