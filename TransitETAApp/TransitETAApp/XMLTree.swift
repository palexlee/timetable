import Foundation

/// Namespace-tolerant XML tree, mirroring xml_util.py: flattens each
/// element to its local tag name (dropping any namespace prefix) so the
/// parser is resilient to namespace/version drift across OJP responses.
final class XMLNode2 {
    let tag: String
    let text: String?
    let children: [XMLNode2]

    init(tag: String, text: String?, children: [XMLNode2]) {
        self.tag = tag
        self.text = text
        self.children = children
    }

    private func findPath(_ path: [String]) -> XMLNode2? {
        var current: [XMLNode2] = [self]
        for tag in path {
            current = current.flatMap { node in node.children.filter { $0.tag == tag } }
            if current.isEmpty { return nil }
        }
        return current.first
    }

    /// Depth-first, first-match lookup of a nested tag path (each argument
    /// is one level deeper, matching only direct children at each step).
    func find(_ path: String...) -> XMLNode2? {
        findPath(path)
    }

    /// All descendants (any depth) with the given local tag name.
    func findAll(_ tag: String) -> [XMLNode2] {
        var results: [XMLNode2] = []
        for child in children {
            if child.tag == tag { results.append(child) }
            results.append(contentsOf: child.findAll(tag))
        }
        return results
    }

    func textOf(_ path: String...) -> String? {
        guard let node = findPath(path), let text = node.text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private func buildNode(from element: XMLElement) -> XMLNode2 {
    let childElements = (element.children ?? []).compactMap { $0 as? XMLElement }
    let children = childElements.map(buildNode)
    let tag = element.localName ?? element.name ?? ""
    let rawText = childElements.isEmpty ? element.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    let text = (rawText?.isEmpty ?? true) ? nil : rawText
    return XMLNode2(tag: tag, text: text, children: children)
}

/// Parses an OJP response body into a namespace-tolerant tree. A degraded
/// backend can return a 2xx response with a non-XML body (a maintenance
/// page, an empty body, ...) -- that must surface as a normal OjpError,
/// not an uncaught Foundation parse error, since the app polls on a timer
/// and must never crash outright.
func parseXML(_ data: Data) throws -> XMLNode2 {
    let document: XMLDocument
    do {
        document = try XMLDocument(data: data, options: [])
    } catch {
        throw OjpError(message: "OJP API returned a non-XML response: \(error.localizedDescription)")
    }
    guard let root = document.rootElement() else {
        throw OjpError(message: "OJP API returned a non-XML response: no root element")
    }
    return buildNode(from: root)
}
