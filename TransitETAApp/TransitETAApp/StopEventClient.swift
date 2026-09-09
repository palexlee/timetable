import Foundation

func buildStopEventRequest(stopRef: String, numberOfResults: Int) -> Data {
    let timestamp = isoNow()
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri" version="2.0">
      <OJPRequest>
        <siri:ServiceRequest>
          <siri:RequestTimestamp>\(timestamp)</siri:RequestTimestamp>
          <siri:RequestorRef>transit-eta-swiftui</siri:RequestorRef>
          <OJPStopEventRequest>
            <siri:RequestTimestamp>\(timestamp)</siri:RequestTimestamp>
            <Location>
              <PlaceRef>
                <StopPlaceRef>\(stopRef)</StopPlaceRef>
              </PlaceRef>
              <DepArrTime>\(timestamp)</DepArrTime>
            </Location>
            <Params>
              <NumberOfResults>\(numberOfResults)</NumberOfResults>
              <StopEventType>departure</StopEventType>
              <IncludeRealtimeData>true</IncludeRealtimeData>
            </Params>
          </OJPStopEventRequest>
        </siri:ServiceRequest>
      </OJPRequest>
    </OJP>
    """
    return xml.data(using: .utf8)!
}

private let isoTimeWithFraction: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private let isoTimeNoFraction: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

func parseOJPTime(_ text: String?) -> Date? {
    guard let text, !text.isEmpty else { return nil }
    return isoTimeWithFraction.date(from: text) ?? isoTimeNoFraction.date(from: text)
}

private func parseStopEvent(_ node: XMLNode2) -> StopEvent? {
    guard let service = node.find("StopEvent", "Service"),
          let call = node.find("StopEvent", "ThisCall", "CallAtStop") else { return nil }

    let mode = service.textOf("Mode", "PtMode") ?? ""
    // Real OJP responses send PublicCode, not PublishedLineName -- verified
    // against the live API. Keep the fallback chain in this order.
    let lineName = service.textOf("PublishedLineName", "Text")
        ?? service.textOf("PublicCode")
        ?? service.textOf("LineRef")
        ?? "?"
    let destination = service.textOf("DestinationText", "Text")
        ?? service.textOf("DestinationStopPointRef")
        ?? "?"

    guard let departure = call.find("ServiceDeparture") else { return nil }
    guard let scheduled = parseOJPTime(departure.textOf("TimetabledTime")) else { return nil }
    let estimated = parseOJPTime(departure.textOf("EstimatedTime"))
    let platform = call.textOf("PlannedQuay", "Text") ?? call.textOf("EstimatedQuay", "Text")

    return StopEvent(
        mode: mode,
        lineName: lineName,
        destination: destination,
        scheduledTime: scheduled,
        estimatedTime: estimated,
        platform: platform
    )
}

func parseStopEventResponse(_ data: Data) throws -> [StopEvent] {
    let root = try parseXML(data)
    let faults = root.findAll("ErrorMessage") + root.findAll("Fault")
    if let fault = faults.first {
        let text = fault.textOf("Text") ?? fault.text ?? "unknown OJP error"
        throw OjpError(message: "OJP returned an error: \(text)")
    }
    var events = root.findAll("StopEventResult").compactMap(parseStopEvent)
    events.sort { $0.bestTime < $1.bestTime }
    return events
}

func nextDepartures(config: Config, limit: Int = 5) async throws -> [StopEvent] {
    guard let apiKey = config.apiKey else {
        throw OjpError(message: "No API key configured (set TRANSIT_ETA_API_KEY or use the menu).")
    }
    guard let stopRef = config.stopRef else {
        throw OjpError(message: "No stop configured yet.")
    }

    var request = URLRequest(url: ojpEndpoint, timeoutInterval: requestTimeoutSeconds)
    request.httpMethod = "POST"
    request.httpBody = buildStopEventRequest(stopRef: stopRef, numberOfResults: limit)
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
    return Array(try parseStopEventResponse(data).prefix(limit))
}
