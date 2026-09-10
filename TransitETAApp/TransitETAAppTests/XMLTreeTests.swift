import XCTest
@testable import TransitETAApp

final class XMLTreeTests: XCTestCase {
    func testParsesSimpleXMLAndStripsNamespacePrefixes() throws {
        let xml = """
        <?xml version="1.0"?>
        <root xmlns:siri="http://www.siri.org.uk/siri">
          <siri:Status>true</siri:Status>
          <Place><Name>Bern</Name></Place>
        </root>
        """.data(using: .utf8)!
        let root = try parseXML(xml)
        XCTAssertEqual(root.textOf("Status"), "true")
        XCTAssertEqual(root.textOf("Place", "Name"), "Bern")
    }

    func testFindAllReturnsEveryMatchingDescendantAtAnyDepth() throws {
        let xml = "<root><a><item>1</item></a><b><item>2</item></b></root>".data(using: .utf8)!
        let root = try parseXML(xml)
        let items = root.findAll("item")
        XCTAssertEqual(items.map { $0.text }, ["1", "2"])
    }

    func testTextOfReturnsNilForMissingPath() throws {
        let xml = "<root><a>1</a></root>".data(using: .utf8)!
        let root = try parseXML(xml)
        XCTAssertNil(root.textOf("missing"))
    }

    func testTextOfReturnsNilForBlankText() throws {
        let xml = "<root><a>   </a></root>".data(using: .utf8)!
        let root = try parseXML(xml)
        XCTAssertNil(root.textOf("a"))
    }

    func testNonXMLBodyThrowsOjpErrorNotAFoundationParseError() {
        let body = "Service Unavailable".data(using: .utf8)!
        XCTAssertThrowsError(try parseXML(body)) { error in
            XCTAssertTrue(error is OjpError, "expected OjpError, got \(type(of: error))")
        }
    }

    func testEmptyBodyThrowsOjpError() {
        XCTAssertThrowsError(try parseXML(Data())) { error in
            XCTAssertTrue(error is OjpError)
        }
    }
}
