import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum OpenerError: Error, LocalizedError, Equatable {
    case missingAPIKey
    case http(status: Int, message: String)
    case refused
    case badResponse(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add your Claude API key in Settings to get personalized openers."
        case let .http(status, message): return "Claude API error \(status): \(message)"
        case .refused: return "Claude declined to write openers for this request."
        case let .badResponse(detail): return "Couldn't read Claude's response (\(detail))."
        }
    }
}

/// Writes personalized conversation starters with the Claude Messages API — one request for everyone
/// on the list, so a refresh is a single round-trip. The app calls this; the widget never does.
public struct OpenerGenerator: Sendable {
    public static let defaultModel = "claude-opus-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public var apiKey: String
    public var model: String
    public var session: URLSession

    public init(apiKey: String, model: String = OpenerGenerator.defaultModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    public func generate(for people: [Person], context: LifeContext, now: Date = .now) async throws -> [UUID: Opener] {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw OpenerError.missingAPIKey }
        guard !people.isEmpty else { return [:] }

        var request = URLRequest(url: Self.endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try Self.requestBody(model: model, people: people, context: context, now: now)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.error.message
                ?? String(decoding: data.prefix(300), as: UTF8.self)
            throw OpenerError.http(status: status, message: message)
        }
        return try Self.parse(data, people: people, now: now)
    }

    // MARK: - Request

    static let systemPrompt = """
    You help someone who finds it hard to start text conversations stay in touch with family and friends.
    For each person, write ONE short text message they could send right now to start a conversation.

    - Sound like a real person texting: casual, warm, 1–2 sentences, under 160 characters. No hashtags, no sign-off.
    - Match the relationship (a parent, a sibling, a coworker and an old friend get different tones).
    - Make it specific when you can: reference the person's notes, or something real from the sender's week
      or projects that this person would plausibly care about. Don't force a project into every message.
    - End with an easy question so the other person has something to reply to.
    - If it's been a long time, acknowledge it lightly without guilt ("it's been a minute!").
    - Never invent facts about either person beyond what's given.
    """

    static func requestBody(model: String, people: [Person], context: LifeContext, now: Date) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4000,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userPrompt(people: people, context: context, now: now)]],
            "output_config": [
                // Short, simple writing: low effort keeps the widget refresh fast and cheap.
                "effort": "low",
                "format": ["type": "json_schema", "schema": schema],
            ],
            // If a request is ever declined, the API retries it on a suitable model in the same call.
            "fallbacks": "default",
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    static let schema: [String: Any] = [
        "type": "object",
        "properties": [
            "openers": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "ref": ["type": "string"],
                        "text": ["type": "string"],
                    ],
                    "required": ["ref", "text"],
                    "additionalProperties": false,
                ],
            ],
        ],
        "required": ["openers"],
        "additionalProperties": false,
    ]

    static func userPrompt(people: [Person], context: LifeContext, now: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"
        var lines = ["Today is \(dateFormatter.string(from: now)).", "", "About me (the sender):"]
        if context.isEmpty {
            lines.append("- Nothing specific shared.")
        } else {
            if !context.projects.isEmpty {
                lines.append("- Projects I'm working on: " + context.projects.joined(separator: "; "))
            }
            let notes = context.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty { lines.append("- My week: " + notes) }
            if !context.upcomingEvents.isEmpty {
                lines.append("- On my calendar soon: " + context.upcomingEvents.prefix(8).joined(separator: "; "))
            }
        }
        lines.append("")
        lines.append("People to write openers for (use the ref exactly):")
        for (i, p) in people.enumerated() {
            var parts = ["ref: p\(i)", "name: \(p.firstName)"]
            if !p.relationship.isEmpty { parts.append("relationship: \(p.relationship)") }
            if let last = p.lastContacted {
                let days = max(0, Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0)
                parts.append("last texted: \(days) days ago")
            } else {
                parts.append("last texted: not recently")
            }
            let notes = p.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty { parts.append("notes: \(notes.replacingOccurrences(of: "\n", with: " / "))") }
            lines.append("- " + parts.joined(separator: " | "))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Response

    struct APIErrorEnvelope: Decodable {
        struct Inner: Decodable { let message: String }
        let error: Inner
    }

    struct MessageResponse: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }
        let content: [Block]
        let stop_reason: String?
    }

    struct Payload: Decodable {
        struct Item: Decodable { let ref: String; let text: String }
        let openers: [Item]
    }

    static func parse(_ data: Data, people: [Person], now: Date) throws -> [UUID: Opener] {
        let message: MessageResponse
        do {
            message = try JSONDecoder().decode(MessageResponse.self, from: data)
        } catch {
            throw OpenerError.badResponse("unexpected shape")
        }
        if message.stop_reason == "refusal" { throw OpenerError.refused }
        // Thinking and fallback blocks can appear alongside the answer; only text blocks carry the JSON.
        let json = message.content.filter { $0.type == "text" }.compactMap(\.text).joined()
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(json.utf8)) else {
            throw OpenerError.badResponse(message.stop_reason == "max_tokens" ? "cut off" : "invalid JSON")
        }
        var result: [UUID: Opener] = [:]
        for item in payload.openers {
            guard item.ref.hasPrefix("p"), let i = Int(item.ref.dropFirst()), people.indices.contains(i) else { continue }
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            result[people[i].id] = Opener(personID: people[i].id, text: text, isAI: true, createdAt: now)
        }
        return result
    }

    // MARK: - Staleness

    /// Fingerprint of everything that shapes an opener. When it changes, cached openers get rewritten.
    public static func inputHash(people: [Person], context: LifeContext) -> String {
        var s = context.projects.joined(separator: "\u{1}") + "\u{2}" + context.notes + "\u{2}"
            + context.upcomingEvents.joined(separator: "\u{1}")
        for p in people {
            s += "\u{2}\(p.id.uuidString)|\(p.name)|\(p.relationship)|\(p.notes)"
        }
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325 // FNV-1a
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}
