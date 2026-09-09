import Foundation

func buildLocationRequest(query: String, numberOfResults: Int) -> Data {
    let timestamp = isoNow()
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri" version="2.0">
      <OJPRequest>
        <siri:ServiceRequest>
          <siri:RequestTimestamp>\(timestamp)</siri:RequestTimestamp>
          <siri:RequestorRef>transit-eta-swiftui</siri:RequestorRef>
          <OJPLocationInformationRequest>
            <siri:RequestTimestamp>\(timestamp)</siri:RequestTimestamp>
            <InitialInput>
              <Name>\(xmlEscape(query))</Name>
            </InitialInput>
            <Restrictions>
              <Type>stop</Type>
              <NumberOfResults>\(numberOfResults)</NumberOfResults>
            </Restrictions>
          </OJPLocationInformationRequest>
        </siri:ServiceRequest>
      </OJPRequest>
    </OJP>
    """
    return xml.data(using: .utf8)!
}

private func parsePlaceResult(_ node: XMLNode2) -> StopMatch? {
    guard let place = node.find("Place") else { return nil }
    let stopRef = place.textOf("StopPlace", "StopPlaceRef") ?? place.textOf("StopPoint", "StopPointRef")
    let name = place.textOf("StopPlace", "StopPlaceName", "Text") ?? place.textOf("Name", "Text")
    guard let stopRef, let name else { return nil }
    let probability = node.textOf("Probability").flatMap(Double.init)
    return StopMatch(stopRef: stopRef, name: name, probability: probability)
}

func parseLocationResponse(_ data: Data) throws -> [StopMatch] {
    let root = try parseXML(data)
    var matches = root.findAll("PlaceResult").compactMap(parsePlaceResult)
    matches.sort { ($0.probability ?? 0) > ($1.probability ?? 0) }
    return matches
}

func searchStops(config: Config, query: String, limit: Int = 8) async throws -> [StopMatch] {
    guard let apiKey = config.apiKey else {
        throw OjpError(message: "No API key configured (set TRANSIT_ETA_API_KEY or use the menu).")
    }
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return [] }

    var request = URLRequest(url: ojpEndpoint, timeoutInterval: requestTimeoutSeconds)
    request.httpMethod = "POST"
    request.httpBody = buildLocationRequest(query: trimmed, numberOfResults: limit)
    var headers = authHeaders(apiKey: apiKey)
    headers["Content-Type"] = "application/xml"
    headers["Accept"] = "application/xml"
    for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }

    let data: Data
    let response: URLResponse
    do {
        (data, response) = try await URLSession.shared.data(for: request)
    } catch {
        throw OjpError(message: "Could not reach OJP API: \(error.localizedDescription)")
    }
    guard let http = response as? HTTPURLResponse else {
        throw OjpError(message: "Could not reach OJP API: no HTTP response")
    }
    guard (200..<300).contains(http.statusCode) else {
        throw ojpError(fromHTTPResponse: http, body: data)
    }
    return Array(try parseLocationResponse(data).prefix(limit))
}
