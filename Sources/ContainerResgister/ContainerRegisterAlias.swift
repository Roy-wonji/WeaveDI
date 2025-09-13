//
//  ContainerRegisterAlias.swift
//  DiContainer
//
//  Created by Wonja Suh on 3/24/25.
//

import Foundation

/// 사용자가 원하는 ContainerRegister 이름으로 사용할 수 있도록 typealias 제공
/// 
/// ## 사용법:
/// ```swift
/// public static var liveValue: BookListInterface = {
///     let repository = ContainerRegister.register(\.bookListInterface) {
///         BookListRepositoryImpl()
///     }
///     return BookListUseCaseImpl(repository: repository)
/// }()
/// ```
public typealias ContainerRegister = RegisterAndReturn