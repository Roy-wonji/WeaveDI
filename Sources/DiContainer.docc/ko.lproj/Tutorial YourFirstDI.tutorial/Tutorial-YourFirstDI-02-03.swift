import Foundation

// MARK: - User Model

struct User: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let username: String
    let email: String
    let phone: String
    let website: String
    let company: Company
    let address: Address
}

// MARK: - Company Model

struct Company: Codable, Sendable {
    let name: String
    let catchPhrase: String
    let bs: String
}

// MARK: - Address Model

struct Address: Codable, Sendable {
    let street: String
    let suite: String
    let city: String
    let zipcode: String
    let geo: Geo
}

// MARK: - Geo Model

struct Geo: Codable, Sendable {
    let lat: String
    let lng: String
}