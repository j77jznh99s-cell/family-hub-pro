import XCTest
@testable import FamilyHubCore

final class SuggestionEngineTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let now = ISO8601DateFormatter().date(from: "2026-09-22T15:00:00Z")!

    func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now)! }

    func testOverduePeopleRankFirstAndUpToDateAreHidden() {
        let mom = Person(name: "Mom", cadenceDays: 3, lastContacted: daysAgo(9))      // 3.0 → overdue
        let bro = Person(name: "Jake", cadenceDays: 7, lastContacted: daysAgo(7))     // 1.0 → due
        let pal = Person(name: "Sam", cadenceDays: 14, lastContacted: daysAgo(11))    // 0.79 → due soon
        let fresh = Person(name: "Ana", cadenceDays: 7, lastContacted: daysAgo(1))    // up to date

        let s = SuggestionEngine.suggestions(people: [fresh, pal, bro, mom], openers: [:], context: .init(), now: now, calendar: cal)
        XCTAssertEqual(s.map(\.person.name), ["Mom", "Jake", "Sam"])
        XCTAssertEqual(s.map(\.urgency), [.overdue, .due, .dueSoon])
        XCTAssertEqual(s.first?.daysSince, 9)
        XCTAssertEqual(s.first?.sinceLabel, "9 days")
    }

    func testNeverContactedCountsAsOverdue() {
        let p = Person(name: "Grandpa Joe")
        let s = SuggestionEngine.suggestions(people: [p], openers: [:], context: .init(), now: now, calendar: cal)
        XCTAssertEqual(s.first?.urgency, .overdue)
        XCTAssertNil(s.first?.daysSince)
        XCTAssertEqual(s.first?.sinceLabel, "Not texted yet")
    }

    func testFavoritesBreakTiesWithinUrgency() {
        let a = Person(name: "Aaron", cadenceDays: 7, lastContacted: daysAgo(14))
        let b = Person(name: "Beth", cadenceDays: 7, lastContacted: daysAgo(12), isFavorite: true)
        let s = SuggestionEngine.suggestions(people: [a, b], openers: [:], context: .init(), now: now, calendar: cal)
        XCTAssertEqual(s.map(\.person.name), ["Beth", "Aaron"])
    }

    func testSnoozedPeopleAreHiddenUntilSnoozeEnds() {
        var p = Person(name: "Dad", cadenceDays: 2, lastContacted: daysAgo(10))
        p.snoozedUntil = cal.date(byAdding: .day, value: 1, to: now)
        XCTAssertTrue(SuggestionEngine.suggestions(people: [p], openers: [:], context: .init(), now: now, calendar: cal).isEmpty)
        let later = cal.date(byAdding: .day, value: 2, to: now)!
        XCTAssertEqual(SuggestionEngine.suggestions(people: [p], openers: [:], context: .init(), now: later, calendar: cal).count, 1)
    }

    func testFreshAIOpenerIsUsedAndStaleOneFallsBack() {
        let p = Person(name: "Mom", cadenceDays: 3, lastContacted: daysAgo(9))
        let fresh = Opener(personID: p.id, text: "AI hello", isAI: true, createdAt: now.addingTimeInterval(-3600))
        var s = SuggestionEngine.suggestions(people: [p], openers: [p.id: fresh], context: .init(), now: now, calendar: cal)
        XCTAssertEqual(s.first?.opener.text, "AI hello")

        let stale = Opener(personID: p.id, text: "AI hello", isAI: true, createdAt: now.addingTimeInterval(-2 * 86400))
        s = SuggestionEngine.suggestions(people: [p], openers: [p.id: stale], context: .init(), now: now, calendar: cal)
        XCTAssertEqual(s.first?.opener.isAI, false)
        XCTAssertTrue(s.first!.opener.text.contains("Mom"))
    }

    func testFallbackOpenerIsStableWithinADayAndUsesFirstName() {
        let p = Person(name: "Maya Lopez", notes: "New job at the hospital")
        let a = SuggestionEngine.fallbackOpener(for: p, context: .init(projects: ["the Family Hub app"]), now: now, calendar: cal)
        let b = SuggestionEngine.fallbackOpener(for: p, context: .init(projects: ["the Family Hub app"]), now: now.addingTimeInterval(3600), calendar: cal)
        XCTAssertEqual(a.text, b.text)
        XCTAssertTrue(a.text.contains("Maya"))
        XCTAssertFalse(a.text.contains("Lopez"))
    }
}

final class AppDataTests: XCTestCase {
    func testMarkContactedResetsClockSnoozeAndOpener() {
        var p = Person(name: "Mom", cadenceDays: 3, lastContacted: Date(timeIntervalSince1970: 0))
        p.snoozedUntil = .distantFuture
        var data = AppData(people: [p], openers: [p.id: Opener(personID: p.id, text: "x", isAI: true)])
        data.markContacted(p.id)
        XCTAssertNotNil(data.people[0].lastContacted)
        XCTAssertGreaterThan(data.people[0].lastContacted!, Date(timeIntervalSince1970: 0))
        XCTAssertNil(data.people[0].snoozedUntil)
        XCTAssertNil(data.openers[p.id])
        XCTAssertTrue(data.suggestions().isEmpty)
    }

    func testStoreRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fh-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = Store(url: url)
        XCTAssertEqual(store.load(), AppData())

        let when = Date(timeIntervalSince1970: 1_790_000_000)
        let p = Person(name: "Jake", relationship: "brother", phone: "555-0100", cadenceDays: 5, lastContacted: when)
        let data = AppData(
            people: [p],
            openers: [p.id: Opener(personID: p.id, text: "yo", isAI: true, createdAt: when)],
            context: LifeContext(projects: ["Family Hub"], notes: "busy week", upcomingEvents: ["Dentist"]),
            openersRefreshedAt: when,
            openersInputHash: "abc"
        )
        try store.save(data)
        XCTAssertEqual(store.load(), data)
    }
}

final class OpenerGeneratorTests: XCTestCase {
    let people = [
        Person(name: "Mom", relationship: "mother", phone: "555-0101", notes: "Garden is finally blooming"),
        Person(name: "Jake Smith", relationship: "brother", phone: "555-0102"),
    ]

    func testRequestBodyShape() throws {
        let data = try OpenerGenerator.requestBody(
            model: "claude-opus-5", people: people,
            context: LifeContext(projects: ["Family Hub app"], notes: "", upcomingEvents: ["Jake's birthday"]),
            now: Date()
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-opus-5")
        XCTAssertEqual(json["fallbacks"] as? String, "default")
        let config = try XCTUnwrap(json["output_config"] as? [String: Any])
        XCTAssertEqual(config["effort"] as? String, "low")
        XCTAssertEqual((config["format"] as? [String: Any])?["type"] as? String, "json_schema")
        let prompt = try XCTUnwrap(((json["messages"] as? [[String: Any]])?.first)?["content"] as? String)
        XCTAssertTrue(prompt.contains("ref: p0 | name: Mom | relationship: mother"))
        XCTAssertTrue(prompt.contains("ref: p1 | name: Jake"))
        XCTAssertTrue(prompt.contains("Family Hub app"))
        XCTAssertTrue(prompt.contains("Jake's birthday"))
        XCTAssertFalse(prompt.contains("555-01"), "phone numbers must never be sent")
        XCTAssertFalse(prompt.contains("Smith"), "only first names are sent")
    }

    func testParseMapsRefsBackToPeopleAndSkipsNonTextBlocks() throws {
        let inner = #"{"openers":[{"ref":"p1","text":"  Yo Jake, how's it going?  "},{"ref":"p9","text":"ghost"},{"ref":"p0","text":"Hi Mom! How's the garden?"}]}"#
        let body: [String: Any] = [
            "stop_reason": "end_turn",
            "content": [
                ["type": "thinking", "thinking": ""],
                ["type": "text", "text": inner],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let result = try OpenerGenerator.parse(data, people: people, now: Date())
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[people[1].id]?.text, "Yo Jake, how's it going?")
        XCTAssertEqual(result[people[0].id]?.text, "Hi Mom! How's the garden?")
        XCTAssertEqual(result[people[0].id]?.isAI, true)
    }

    func testParseRefusal() throws {
        let data = try JSONSerialization.data(withJSONObject: ["stop_reason": "refusal", "content": []])
        XCTAssertThrowsError(try OpenerGenerator.parse(data, people: people, now: Date())) {
            XCTAssertEqual($0 as? OpenerError, .refused)
        }
    }

    func testMissingKeyThrowsBeforeNetwork() async {
        do {
            _ = try await OpenerGenerator(apiKey: " ").generate(for: people, context: .init())
            XCTFail("expected missingAPIKey")
        } catch {
            XCTAssertEqual(error as? OpenerError, .missingAPIKey)
        }
    }

    func testInputHashChangesWithContext() {
        let a = OpenerGenerator.inputHash(people: people, context: .init(projects: ["A"]))
        let b = OpenerGenerator.inputHash(people: people, context: .init(projects: ["B"]))
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, OpenerGenerator.inputHash(people: people, context: .init(projects: ["A"])))
    }
}
