import Foundation

let ojpEndpoint = URL(string: "https://api.opentransportdata.swiss/ojp20")!
let requestTimeoutSeconds: TimeInterval = 15
let userAgent = "transit-eta-swiftui/1.0"

struct OjpError: Error, LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

func authHeaders(apiKey: String) -> [String: String] {
    ["Authorization": "Bearer \(apiKey)", "User-Agent": userAgent]
}

func isoNow() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: Date())
}

func xmlEscape(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

// exc.reason from urllib is just the status phrase; the body usually
// carries the actual reason (invalid/expired key, quota exceeded, ...),
// so surface it -- mirrors ojp_http.py's error_from_http_error.
func ojpError(fromHTTPResponse response: HTTPURLResponse, body: Data) -> OjpError {
    var detail = String(data: body, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if detail.isEmpty {
        detail = HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
    } else if detail.count > 300 {
        detail = String(detail.prefix(300))
    }
    return OjpError(message: "HTTP \(response.statusCode) from OJP API: \(detail)")
}
