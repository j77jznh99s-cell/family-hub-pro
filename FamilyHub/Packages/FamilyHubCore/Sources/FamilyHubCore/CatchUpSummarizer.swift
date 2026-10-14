import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Turns a catch-up recording's transcript into a short summary, a note worth keeping on that
/// person's profile, and a checklist of anything you said you'd follow up on. Mirrors
/// `OpenerGenerator`'s shape exactly (same request building, same error handling, same privacy
/// stance), including reusing `OpenerError` — the same four failure shapes apply here too.
public struct CatchUpSummarizer: Sendable {
    public static let defaultModel = OpenerGenerator.defaultModel

    public var apiKey: String
    public var model: String
    public var session: URLSession

    public init(apiKey: String, model: String = CatchUpSummarizer.defaultModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    /// Reads the transcript of a catch-up conversation and writes a summary, a note for the
    /// person's profile, and any concrete follow-ups the sender mentioned. Only `person.firstName`,
    /// `relationship` and existing `notes` are ever sent as context — never phone numbers or last names.
    public func summarize(transcript: String, person: Person?, now: Date = .now) async throws -> (summary: String, suggestedNote: String, actionItems: [String]) {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw OpenerError.missingAPIKey }
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (summary: "", suggestedNote: "", actionItems: []) }

        var request = URLRequest(url: OpenerGenerator.endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try Self.requestBody(model: model, transcript: trimmed, person: person, now: now)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(OpenerGenerator.APIErrorEnvelope.self, from: data))?.error.message
                ?? String(decoding: data.prefix(300), as: UTF8.self)
            throw OpenerError.http(status: status, message: message)
        }
        return try Self.parseSummary(data)
    }

    /// A single free-text follow-up question, answered only from the transcript's content. Takes
    /// `apiKey`/`model`/`session` directly rather than an instance, since it has no person context
    /// to carry between calls.
    public static func ask(question: String, transcript: String, apiKey: String, model: String = CatchUpSummarizer.defaultModel, session: URLSession = .shared) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw OpenerError.missingAPIKey }
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !t.isEmpty else { return "" }

        var request = URLRequest(url: OpenerGenerator.endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try askRequestBody(model: model, question: q, transcript: t)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(OpenerGenerator.APIErrorEnvelope.self, from: data))?.error.message
                ?? String(decoding: data.prefix(300), as: UTF8.self)
            throw OpenerError.http(status: status, message: message)
        }
        return try parseAnswer(data)
    }

    // MARK: - Summarize request

    static let summarizeSystemPrompt = """
    You read a transcript of a phone call or in-person conversation recap with a family member or
    friend, and help someone keep track of what was actually discussed.

    Write:
    - summary: ONE sentence capturing what the conversation was about.
    - suggestedNote: a short note worth remembering for next time, in the same style as a running
      note like "the new job" or "the Denver trip" — a few words to a short phrase, not a full sentence.
    - actionItems: concrete things the SENDER (the person recording this, not the family member or
      friend) said they'd follow up on, like "call the doctor's office for her" or "send those photos".
      Use an empty array if there genuinely aren't any — never invent one just to fill the list.

    Never invent facts beyond what's in the transcript.
    """

    static func requestBody(model: String, transcript: String, person: Person?, now: Date) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": summarizeSystemPrompt,
            "messages": [["role": "user", "content": summarizeUserPrompt(transcript: transcript, person: person, now: now)]],
            "output_config": [
                // Short, simple writing: low effort keeps this fast and cheap.
                "effort": "low",
                "format": ["type": "json_schema", "schema": summarySchema],
            ],
            // If a request is ever declined, the API retries it on a suitable model in the same call.
            "fallbacks": "default",
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    static let summarySchema: [String: Any] = [
        "type": "object",
        "properties": [
            "summary": ["type": "string"],
            "suggestedNote": ["type": "string"],
            "actionItems": [
                "type": "array",
                "items": ["type": "string"],
            ],
        ],
        "required": ["summary", "suggestedNote", "actionItems"],
        "additionalProperties": false,
    ]

    static func summarizeUserPrompt(transcript: String, person: Person?, now: Date) -> String {
        var lines: [String] = []
        if let person {
            var parts = ["name: \(person.firstName)"]
            if !person.relationship.isEmpty { parts.append("relationship: \(person.relationship)") }
            let notes = person.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty { parts.append("what I already know about them: \(notes.replacingOccurrences(of: "\n", with: " / "))") }
            lines.append("This conversation was with: " + parts.joined(separator: " | "))
        } else {
            lines.append("The person on this call hasn't been identified yet.")
        }
        lines.append("")
        lines.append("Transcript:")
        lines.append(transcript)
        return lines.joined(separator: "\n")
    }

    struct SummaryPayload: Decodable {
        let summary: String
        let suggestedNote: String
        let actionItems: [String]
    }

    static func parseSummary(_ data: Data) throws -> (summary: String, suggestedNote: String, actionItems: [String]) {
        let message: OpenerGenerator.MessageResponse
        do {
            message = try JSONDecoder().decode(OpenerGenerator.MessageResponse.self, from: data)
        } catch {
            throw OpenerError.badResponse("unexpected shape")
        }
        if message.stop_reason == "refusal" { throw OpenerError.refused }
        // Thinking and fallback blocks can appear alongside the answer; only text blocks carry the JSON.
        let json = message.content.filter { $0.type == "text" }.compactMap(\.text).joined()
        guard let payload = try? JSONDecoder().decode(SummaryPayload.self, from: Data(json.utf8)) else {
            throw OpenerError.badResponse(message.stop_reason == "max_tokens" ? "cut off" : "invalid JSON")
        }
        return (
            summary: payload.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            suggestedNote: payload.suggestedNote.trimmingCharacters(in: .whitespacesAndNewlines),
            actionItems: payload.actionItems
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    // MARK: - Ask request

    static let askSystemPrompt = """
    You answer a short follow-up question about one conversation transcript. Answer only using what's
    in the transcript — if it isn't there, say so plainly. Keep the answer short and direct: a
    sentence or two.
    """

    static func askUserPrompt(question: String, transcript: String) -> String {
        "Transcript:\n\(transcript)\n\nQuestion: \(question)"
    }

    static func askRequestBody(model: String, question: String, transcript: String) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 512,
            "system": askSystemPrompt,
            "messages": [["role": "user", "content": askUserPrompt(question: question, transcript: transcript)]],
            "output_config": ["effort": "low"],
            "fallbacks": "default",
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    static func parseAnswer(_ data: Data) throws -> String {
        let message: OpenerGenerator.MessageResponse
        do {
            message = try JSONDecoder().decode(OpenerGenerator.MessageResponse.self, from: data)
        } catch {
            throw OpenerError.badResponse("unexpected shape")
        }
        if message.stop_reason == "refusal" { throw OpenerError.refused }
        let text = message.content.filter { $0.type == "text" }.compactMap(\.text).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw OpenerError.badResponse(message.stop_reason == "max_tokens" ? "cut off" : "empty")
        }
        return text
    }
}
