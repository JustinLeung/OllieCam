import Foundation

struct SSEEvent: Sendable {
    let type: DetectionType
    let confidence: Double
    let timestamp: Date
    let clip: ClipMetadata?
}

actor SSEClient {
    private var configuration: ServerConfiguration
    private var task: Task<Void, Never>?
    private var reconnectDelay: TimeInterval = Constants.SSE.initialReconnectDelay

    private var continuation: AsyncStream<SSEEvent>.Continuation?
    private(set) var isConnected: Bool = false

    init(configuration: ServerConfiguration = .empty) {
        self.configuration = configuration
    }

    func updateConfiguration(_ configuration: ServerConfiguration) {
        self.configuration = configuration
    }

    func connect() -> AsyncStream<SSEEvent> {
        disconnect()

        let (stream, continuation) = AsyncStream.makeStream(of: SSEEvent.self)
        self.continuation = continuation

        task = Task { [weak self] in
            guard let self else { return }
            await self.connectionLoop()
        }

        return stream
    }

    func disconnect() {
        task?.cancel()
        task = nil
        continuation?.finish()
        continuation = nil
        isConnected = false
        reconnectDelay = Constants.SSE.initialReconnectDelay
    }

    private func connectionLoop() async {
        while !Task.isCancelled {
            do {
                try await startListening()
            } catch {
                if Task.isCancelled { break }
                isConnected = false
                try? await Task.sleep(for: .seconds(reconnectDelay))
                reconnectDelay = min(
                    reconnectDelay * Constants.SSE.reconnectMultiplier,
                    Constants.SSE.maxReconnectDelay
                )
            }
        }
    }

    private func startListening() async throws {
        guard let url = configuration.baseURL?.appendingPathComponent("events") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        if let auth = configuration.authHeader {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let session = URLSession(configuration: .default)
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        isConnected = true
        reconnectDelay = Constants.SSE.initialReconnectDelay

        var dataBuffer = ""

        for try await line in bytes.lines {
            if Task.isCancelled { break }

            if line.hasPrefix("data:") {
                let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                dataBuffer = data
            } else if line.isEmpty && !dataBuffer.isEmpty {
                parseEvent(dataBuffer)
                dataBuffer = ""
            }
        }
    }

    private func parseEvent(_ data: String) {
        guard let jsonData = data.data(using: .utf8) else { return }

        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            guard let typeString = json?["type"] as? String,
                  let type = DetectionType(rawValue: typeString),
                  let confidence = json?["confidence"] as? Double else {
                return
            }

            let timestamp: Date
            if let ts = json?["timestamp"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                timestamp = formatter.date(from: ts) ?? .now
            } else {
                timestamp = .now
            }

            var clipMetadata: ClipMetadata?
            if let clipJSON = json?["clip"] as? [String: Any],
               let clipData = try? JSONSerialization.data(withJSONObject: clipJSON) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                clipMetadata = try? decoder.decode(ClipMetadata.self, from: clipData)
            }

            let event = SSEEvent(
                type: type,
                confidence: confidence,
                timestamp: timestamp,
                clip: clipMetadata
            )

            continuation?.yield(event)
        } catch {
            // Ignore malformed events
        }
    }
}
