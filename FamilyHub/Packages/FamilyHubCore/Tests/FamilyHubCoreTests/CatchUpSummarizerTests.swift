import XCTest
@testable import FamilyHubCore

final class CatchUpSummarizerTests: XCTestCase {
    let mom = Person(name: "Mom Smith", relationship: "mother", phone: "555-0101", notes: "Garden is finally blooming")

    // MARK: Summarize request

    func testSummarizeRequestBodyShape() throws {
        let data = try CatchUpSummarizer.requestBody(
            model: "claude-opus-5",
            transcript: "We talked about her new garden and the Denver trip.",
            person: mom, now: Date()
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-opus-5")
        XCTAssertEqual(json["fallbacks"] as? String, "default")
        let config = try XCTUnwrap(json["output_config"] as? [String: Any])
        XCTAssertEqual(config["effort"] as? String, "low")
        XCTAssertEqual((config["format"] as? [String: Any])?["type"] as? String, "json_schema")
        let prompt = try XCTUnwrap(((json["messages"] as? [[String: Any]])?.first)?["content"] as? String)
        XCTAssertTrue(prompt.contains("name: Mom"))
        XCTAssertTrue(prompt.contains("relationship: mother"))
        XCTAssertTrue(prompt.contains("Garden is finally blooming"))
        XCTAssertTrue(prompt.contains("Denver trip"))
        XCTAssertFalse(prompt.contains("555-01"), "phone numbers must never be sent")
        XCTAssertFalse(prompt.contains("Smith"), "only first names are sent")
    }

    func testSummarizeRequestBodyWithoutPersonStillBuilds() throws {
        let data = try CatchUpSummarizer.requestBody(model: "claude-opus-5", transcript: "Quick recap.", person: nil, now: Date())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let prompt = try XCTUnwrap(((json["messages"] as? [[String: Any]])?.first)?["content"] as? String)
        XCTAssertTrue(prompt.contains("hasn't been identified"))
        XCTAssertTrue(prompt.contains("Quick recap."))
    }

    // MARK: Summarize response

    func testParseSummaryMapsFields() throws {
        let inner = #"{"summary":"Caught up with Mom about the garden.","suggestedNote":"garden finally blooming","actionItems":["send her the photos"]}"#
        let body: [String: Any] = [
            "stop_reason": "end_turn",
            "content": [
                ["type": "thinking", "thinking": ""],
                ["type": "text", "text": inner],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let result = try CatchUpSummarizer.parseSummary(data)
        XCTAssertEqual(result.summary, "Caught up with Mom about the garden.")
        XCTAssertEqual(result.suggestedNote, "garden finally blooming")
        XCTAssertEqual(result.actionItems, ["send her the photos"])
    }

    func testParseSummaryNeverInventsActionItems() throws {
        let inner = #"{"summary":"Quick hello, nothing urgent.","suggestedNote":"","actionItems":[]}"#
        let body: [String: Any] = ["stop_reason": "end_turn", "content": [["type": "text", "text": inner]]]
        let data = try JSONSerialization.data(withJSONObject: body)
        let result = try CatchUpSummarizer.parseSummary(data)
        XCTAssertTrue(result.actionItems.isEmpty)
        XCTAssertEqual(result.suggestedNote, "")
    }

    func testParseSummaryRefusal() throws {
        let data = try JSONSerialization.data(withJSONObject: ["stop_reason": "refusal", "content": []])
        XCTAssertThrowsError(try CatchUpSummarizer.parseSummary(data)) {
            XCTAssertEqual($0 as? OpenerError, .refused)
        }
    }

    func testParseSummaryBadJSONThrowsBadResponse() throws {
        let body: [String: Any] = ["stop_reason": "end_turn", "content": [["type": "text", "text": "not json"]]]
        let data = try JSONSerialization.data(withJSONObject: body)
        XCTAssertThrowsError(try CatchUpSummarizer.parseSummary(data)) {
            guard case .badResponse = $0 as? OpenerError else { return XCTFail("expected badResponse") }
        }
    }

    // MARK: Summarize instance method short-circuits

    func testSummarizeMissingKeyThrowsBeforeNetwork() async {
        do {
            _ = try await CatchUpSummarizer(apiKey: " ").summarize(transcript: "hi", person: nil)
            XCTFail("expected missingAPIKey")
        } catch {
            XCTAssertEqual(error as? OpenerError, .missingAPIKey)
        }
    }

    func testSummarizeEmptyTranscriptSkipsNetwork() async throws {
        let result = try await CatchUpSummarizer(apiKey: "test-key").summarize(transcript: "   ", person: nil)
        XCTAssertEqual(result.summary, "")
        XCTAssertEqual(result.suggestedNote, "")
        XCTAssertTrue(result.actionItems.isEmpty)
    }

    // MARK: Ask request

    func testAskRequestBodyShape() throws {
        let data = try CatchUpSummarizer.askRequestBody(
            model: "claude-opus-5",
            question: "Did she mention the doctor?",
            transcript: "We talked about her doctor's appointment next week."
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-opus-5")
        XCTAssertEqual(json["fallbacks"] as? String, "default")
        let prompt = try XCTUnwrap(((json["messages"] as? [[String: Any]])?.first)?["content"] as? String)
        XCTAssertTrue(prompt.contains("doctor's appointment"))
        XCTAssertTrue(prompt.contains("Did she mention the doctor?"))
    }

    // MARK: Ask response

    func testParseAnswerReturnsTrimmedText() throws {
        let body: [String: Any] = ["stop_reason": "end_turn", "content": [["type": "text", "text": "  Yes, next Tuesday.  "]]]
        let data = try JSONSerialization.data(withJSONObject: body)
        XCTAssertEqual(try CatchUpSummarizer.parseAnswer(data), "Yes, next Tuesday.")
    }

    func testParseAnswerRefusal() throws {
        let data = try JSONSerialization.data(withJSONObject: ["stop_reason": "refusal", "content": []])
        XCTAssertThrowsError(try CatchUpSummarizer.parseAnswer(data)) {
            XCTAssertEqual($0 as? OpenerError, .refused)
        }
    }

    func testParseAnswerEmptyThrowsBadResponse() throws {
        let body: [String: Any] = ["stop_reason": "end_turn", "content": [["type": "text", "text": "   "]]]
        let data = try JSONSerialization.data(withJSONObject: body)
        XCTAssertThrowsError(try CatchUpSummarizer.parseAnswer(data)) {
            guard case .badResponse = $0 as? OpenerError else { return XCTFail("expected badResponse") }
        }
    }

    // MARK: Ask static method short-circuits

    func testAskMissingKeyThrowsBeforeNetwork() async {
        do {
            _ = try await CatchUpSummarizer.ask(question: "what?", transcript: "hi", apiKey: " ")
            XCTFail("expected missingAPIKey")
        } catch {
            XCTAssertEqual(error as? OpenerError, .missingAPIKey)
        }
    }

    func testAskEmptyQuestionOrTranscriptSkipsNetwork() async throws {
        let empty = try await CatchUpSummarizer.ask(question: "  ", transcript: "something was said", apiKey: "test-key")
        XCTAssertEqual(empty, "")
        let noTranscript = try await CatchUpSummarizer.ask(question: "what happened?", transcript: " ", apiKey: "test-key")
        XCTAssertEqual(noTranscript, "")
    }
}
