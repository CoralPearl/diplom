import Foundation

/// Generic paged list response used by backend for list endpoints.
struct PagedResponse<T: Codable>: Codable {
    let items: [T]
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}
