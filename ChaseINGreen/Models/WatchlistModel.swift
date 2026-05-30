//
//  WatchlistModel.swift
//  ChaseINGreen
//
//  Created by Otis Young on 5/26/26.
//


import Foundation

struct WatchlistCreateRequest: Codable {
    let title: String
    let symbols: [String]
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case symbols
        case isDefault = "is_default"
    }
}

struct WatchlistUpdateRequest: Codable {
    let title: String?
    let symbols: [String]?
    let isDefault: Bool?

    enum CodingKeys: String, CodingKey {
        case title
        case symbols
        case isDefault = "is_default"
    }
}

struct CurrentUserResponse: Codable {
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case isAdmin = "is_admin"
    }
}

struct WatchlistResponse: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let symbols: [String]
    let isDefault: Bool
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case symbols
        case isDefault = "is_default"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
