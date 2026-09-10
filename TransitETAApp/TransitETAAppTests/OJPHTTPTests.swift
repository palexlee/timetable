import XCTest
@testable import TransitETAApp

final class OJPHTTPTests: XCTestCase {
    func testAuthHeadersIncludesBearerAndUserAgent() {
        let headers = authHeaders(apiKey: "secret123")
        XCTAssertEqual(headers["Authorization"], "Bearer secret123")
        XCTAssertEqual(headers["User-Agent"], userAgent)
    }

    func testIsoNowFormat() {
        let value = isoNow()
        let regex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
        let range = NSRange(value.startIndex..., in: value)
        XCTAssertNotNil(regex.firstMatch(in: value, range: range))
    }

    func testXmlEscapeEscapesSpecialCharacters() {
        XCTAssertEqual(xmlEscape("<a> & \"b\""), "&lt;a&gt; &amp; &quot;b&quot;")
    }

    func testOjpErrorFromHTTPResponseIncludesStatusAndBody() {
        let url = URL(string: "https://api.opentransportdata.swiss/ojp20")!
        let response = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!
        let body = "Access to this API has been disallowed".data(using: .utf8)!
        let error = ojpError(fromHTTPResponse: response, body: body)
        XCTAssertTrue(error.message.contains("HTTP 403"))
        XCTAssertTrue(error.message.contains("Access to this API has been disallowed"))
    }

    func testOjpErrorTruncatesLongBodies() {
        let url = URL(string: "https://api.opentransportdata.swiss/ojp20")!
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
        let body = Data(repeating: 0x41, count: 500) // 500 'A's
        let error = ojpError(fromHTTPResponse: response, body: body)
        XCTAssertEqual(error.message.count, "HTTP 500 from OJP API: ".count + 300)
    }
}
