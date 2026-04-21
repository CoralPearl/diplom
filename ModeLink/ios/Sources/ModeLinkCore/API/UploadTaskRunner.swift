import Foundation

/// Runs a single `URLSessionUploadTask` with progress callback.
///
/// This is intentionally lightweight and created per upload.
final class UploadTaskRunner: NSObject {
    typealias ProgressHandler = @Sendable (Double) -> Void

    private let onProgress: ProgressHandler
    private var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?

    private var responseData = Data()
    private var httpResponse: HTTPURLResponse?

    private var session: URLSession?

    init(onProgress: @escaping ProgressHandler) {
        self.onProgress = onProgress
    }

    func upload(request: URLRequest, body: Data) async throws -> (Data, HTTPURLResponse) {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        // Delegate queue can be nil; URLSession will manage it.
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let task = session.uploadTask(with: request, from: body)
            task.resume()
        }
    }

    private func finish(result: Result<(Data, HTTPURLResponse), Error>) {
        // Ensure we resume only once.
        guard let cont = continuation else { return }
        continuation = nil

        // Always invalidate.
        session?.invalidateAndCancel()
        session = nil

        cont.resume(with: result)
    }
}

extension UploadTaskRunner: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else {
            DispatchQueue.main.async {
                self.onProgress(0)
            }
            return
        }
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            self.onProgress(min(max(progress, 0), 1))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(result: .failure(error))
            return
        }
        guard let http = httpResponse else {
            finish(result: .failure(APIError.unknown))
            return
        }
        finish(result: .success((responseData, http)))
    }
}

extension UploadTaskRunner: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        httpResponse = response as? HTTPURLResponse
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        responseData.append(data)
    }
}
