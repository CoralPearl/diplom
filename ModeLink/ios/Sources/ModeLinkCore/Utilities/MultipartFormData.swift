import Foundation

struct MultipartFormData {
    let boundary: String
    private(set) var body = Data()

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    mutating func addField(name: String, value: String) {
        var field = ""
        field += "--\(boundary)\r\n"
        field += "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
        field += "\(value)\r\n"
        body.append(field.data(using: .utf8) ?? Data())
    }

    mutating func addFile(name: String, filename: String, mimeType: String, fileData: Data) {
        var filePart = ""
        filePart += "--\(boundary)\r\n"
        filePart += "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
        filePart += "Content-Type: \(mimeType)\r\n\r\n"
        body.append(filePart.data(using: .utf8) ?? Data())
        body.append(fileData)
        body.append("\r\n".data(using: .utf8) ?? Data())
    }

    mutating func finalize() {
        let closing = "--\(boundary)--\r\n"
        body.append(closing.data(using: .utf8) ?? Data())
    }

    var contentTypeHeaderValue: String {
        "multipart/form-data; boundary=\(boundary)"
    }
}
