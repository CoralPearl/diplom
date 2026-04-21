import Foundation

struct ErrorResponse: Decodable {
    struct ZodIssue: Decodable {
        let code: String?
        let expected: String?
        let received: String?
        let path: [String]?
        let message: String?
    }

    let error: String
    let message: String
    let details: [ZodIssue]?
}

enum APIError: LocalizedError {
    case invalidURL
    case offline
    case timeout
    case cancelled
    case network(underlying: Error)
    case server(status: Int, code: String?, message: String)
    case decoding(underlying: Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL"
        case .offline:
            return "Нет подключения к интернету"
        case .timeout:
            return "Превышено время ожидания запроса"
        case .cancelled:
            return "Запрос отменён"
        case .network(let underlying):
            return "Ошибка сети: \(underlying.localizedDescription)"
        case .server(_, _, let message):
            return message
        case .decoding(let underlying):
            return "Ошибка декодирования: \(underlying.localizedDescription)"
        case .unknown:
            return "Неизвестная ошибка"
        }
    }

    var isAuthError: Bool {
        if case .server(let status, _, _) = self {
            return status == 401 || status == 403
        }
        return false
    }

    var isOfflineLike: Bool {
        switch self {
        case .offline:
            return true
        case .network(let underlying):
            if let urlErr = underlying as? URLError {
                return urlErr.code == .notConnectedToInternet
            }
            return false
        default:
            return false
        }
    }

    var isTransient: Bool {
        switch self {
        case .timeout:
            return true
        case .network(let underlying):
            if let urlErr = underlying as? URLError {
                return [
                    URLError.timedOut,
                    URLError.networkConnectionLost,
                    URLError.cannotFindHost,
                    URLError.cannotConnectToHost,
                    URLError.dnsLookupFailed
                ].contains(urlErr.code)
            }
            return false
        case .server(let status, _, _):
            return [502, 503, 504].contains(status)
        default:
            return false
        }
    }
}
