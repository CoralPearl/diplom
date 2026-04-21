import Foundation

final class APIClient {
    static let shared = APIClient()

    /// Change this to your backend URL.
    /// - Simulator: http://localhost:3000
    /// - Device: http://<your-mac-ip>:3000
    var baseURL: URL = URL(string: "http://localhost:3000")!

    /// Injected by AppState.
    var tokenProvider: () -> String? = { nil }

    private let decoder = JSONDecoder.modeLinkDecoder()

    private init() {}

    // MARK: - URL building

    private func makeURL(path: String, query: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        let basePath = components.path
        if basePath.isEmpty || basePath == "/" {
            components.path = cleanPath
        } else {
            // Join paths safely (avoid double slashes)
            let trimmed = cleanPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let joined = (basePath as NSString).appendingPathComponent(trimmed)
            components.path = joined.hasPrefix("/") ? joined : "/\(joined)"
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        return url
    }

    private func prepareRequest(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String? = "application/json",
        requiresAuth: Bool = true,
        idempotencyKey: String? = nil,
        timeout: TimeInterval = 30
    ) throws -> URLRequest {
        let url = try makeURL(path: path, query: query)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = timeout

        if let body {
            req.httpBody = body
        }
        if let contentType {
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if requiresAuth, let token = tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let idempotencyKey, !idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            req.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        return req
    }

    private func decodeServerError(data: Data) -> ErrorResponse? {
        do {
            return try decoder.decode(ErrorResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private func mapNetworkError(_ error: Error) -> APIError {
        // URLSession sometimes wraps URLError in NSError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return .offline
            case .timedOut:
                return .timeout
            case .cancelled:
                return .cancelled
            default:
                return .network(underlying: urlError)
            }
        }

        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            if ns.code == NSURLErrorNotConnectedToInternet {
                return .offline
            }
            if ns.code == NSURLErrorTimedOut {
                return .timeout
            }
            if ns.code == NSURLErrorCancelled {
                return .cancelled
            }
        }

        return .network(underlying: error)
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.unknown
            }
            guard (200...299).contains(http.statusCode) else {
                if let err = decodeServerError(data: data) {
                    throw APIError.server(status: http.statusCode, code: err.error, message: err.message)
                }
                let fallback = String(data: data, encoding: .utf8) ?? "Server error"
                throw APIError.server(status: http.statusCode, code: nil, message: fallback)
            }
            return (data, http)
        } catch let apiErr as APIError {
            throw apiErr
        } catch {
            throw mapNetworkError(error)
        }
    }

    private func shouldRetry(_ error: APIError, method: String) -> Bool {
        // No point retrying when completely offline.
        if error.isOfflineLike { return false }

        // Retry only safe/idempotent methods.
        guard ["GET", "PUT", "PATCH", "DELETE"].contains(method.uppercased()) else {
            return false
        }

        return error.isTransient
    }

    private func sendWithRetry(_ request: URLRequest, maxAttempts: Int = 3) async throws -> (Data, HTTPURLResponse) {
        let method = request.httpMethod ?? "GET"

        var attempt = 0
        var delayNs: UInt64 = 300_000_000 // 0.3s

        while true {
            do {
                return try await send(request)
            } catch let apiErr as APIError {
                attempt += 1
                let canRetry = attempt < maxAttempts && shouldRetry(apiErr, method: method)
                if !canRetry {
                    throw apiErr
                }
                try? await Task.sleep(nanoseconds: delayNs)
                delayNs = min(delayNs * 2, 2_000_000_000) // cap at 2s
            }
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(underlying: error)
        }
    }

    private func cacheKey(for request: URLRequest) -> String {
        let url = request.url?.absoluteString ?? "<no-url>"
        let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
        return "\(url)|\(auth)"
    }

    // MARK: - JSON requests

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], requiresAuth: Bool = true) async throws -> T {
        let req = try prepareRequest(path: path, method: "GET", query: query, requiresAuth: requiresAuth)
        let key = cacheKey(for: req)

        do {
            let (data, _) = try await sendWithRetry(req)
            await ResponseCache.shared.store(data, for: key)
            return try decode(T.self, from: data)
        } catch let apiErr as APIError {
            // Offline-friendly fallback for GET.
            if apiErr.isOfflineLike || apiErr.isTransient {
                if let cached = await ResponseCache.shared.load(for: key) {
                    do {
                        return try decode(T.self, from: cached)
                    } catch {
                        // cached data is corrupted/outdated
                    }
                }
            }
            throw apiErr
        }
    }

    func post<T: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        requiresAuth: Bool = true,
        idempotencyKey: String? = nil
    ) async throws -> T {
        let data = try JSONEncoder().encode(body)
        let req = try prepareRequest(path: path, method: "POST", body: data, requiresAuth: requiresAuth, idempotencyKey: idempotencyKey)
        let (respData, _) = try await send(req)
        return try decode(T.self, from: respData)
    }

    func put<T: Decodable, Body: Encodable>(_ path: String, body: Body, requiresAuth: Bool = true) async throws -> T {
        let data = try JSONEncoder().encode(body)
        let req = try prepareRequest(path: path, method: "PUT", body: data, requiresAuth: requiresAuth)
        let (respData, _) = try await sendWithRetry(req)
        return try decode(T.self, from: respData)
    }


    func patch<T: Decodable, Body: Encodable>(_ path: String, body: Body, requiresAuth: Bool = true) async throws -> T {
        let data = try JSONEncoder().encode(body)
        let req = try prepareRequest(path: path, method: "PATCH", body: data, requiresAuth: requiresAuth)
        let (respData, _) = try await sendWithRetry(req)
        return try decode(T.self, from: respData)
    }

    func delete<T: Decodable>(_ path: String, requiresAuth: Bool = true) async throws -> T {
        let req = try prepareRequest(path: path, method: "DELETE", contentType: nil, requiresAuth: requiresAuth)
        let (respData, _) = try await sendWithRetry(req)
        return try decode(T.self, from: respData)
    }

    // MARK: - Multipart (portfolio upload)

    /// Upload without progress callback.
    func uploadPortfolioImage(
        imageData: Data,
        filename: String,
        mimeType: String,
        modelId: UUID? = nil
    ) async throws -> PortfolioImage {
        return try await uploadPortfolioImage(
            imageData: imageData,
            filename: filename,
            mimeType: mimeType,
            modelId: modelId,
            idempotencyKey: nil,
            onProgress: { _ in }
        )
    }

    /// Upload with progress callback (0...1).
    func uploadPortfolioImage(
        imageData: Data,
        filename: String,
        mimeType: String,
        modelId: UUID? = nil,
        idempotencyKey: String? = nil,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws -> PortfolioImage {
        var form = MultipartFormData()
        if let modelId {
            form.addField(name: "modelId", value: modelId.uuidString)
        }
        form.addFile(name: "image", filename: filename, mimeType: mimeType, fileData: imageData)
        form.finalize()

        var req = try prepareRequest(
            path: "/portfolio",
            method: "POST",
            body: nil,
            contentType: form.contentTypeHeaderValue,
            requiresAuth: true,
            idempotencyKey: idempotencyKey,
            timeout: 120
        )

        // For uploadTask we must not set httpBody.
        req.httpBody = nil

        do {
            let runner = UploadTaskRunner(onProgress: onProgress)
            let (data, http) = try await runner.upload(request: req, body: form.body)

            guard (200...299).contains(http.statusCode) else {
                if let err = decodeServerError(data: data) {
                    throw APIError.server(status: http.statusCode, code: err.error, message: err.message)
                }
                let fallback = String(data: data, encoding: .utf8) ?? "Server error"
                throw APIError.server(status: http.statusCode, code: nil, message: fallback)
            }

            return try decode(PortfolioImage.self, from: data)
        } catch let apiErr as APIError {
            throw apiErr
        } catch {
            throw mapNetworkError(error)
        }
    }
}
