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

    func testFavoriteNeverOutranksAHigherUrgency() {
        let a = Person(name: "Aaron", cadenceDays: 7, lastContacted: daysAgo(14))                  // 2.0 → overdue
        let b = Person(name: "Beth", cadenceDays: 7, lastContacted: daysAgo(7), isFavorite: true)  // 1.0 → due
        let s = SuggestionEngine.suggestions(people: [b, a], openers: [:], context: .init(), now: now, calendar: cal)
        XCTAssertEqual(s.map(\.person.name), ["Aaron", "Beth"])
    }

    func testEqualScoresSortByNameIgnoringCase() {
        let bob = Person(name: "bob", cadenceDays: 7, lastContacted: daysAgo(14))
        let alice = Person(name: "Alice", cadenceDays: 7, lastContacted: daysAgo(14))
        let s = SuggestionEngine.suggestions(people: [bob, alice], openers: [:], context: .init(), now: now, calendar: cal)
        XCTAssertEqual(s.map(\.person.name), ["Alice", "bob"])
    }

    func testUrgencyThresholds() {
        XCTAssertEqual(SuggestionEngine.urgency(forScore: 0), .upToDate)
        XCTAssertEqual(SuggestionEngine.urgency(forScore: 0.74), .upToDate)
        XCTAssertEqual(SuggestionEngine.urgency(forScore: 0.75), .dueSoon)
        XCTAssertEqual(SuggestionEngine.urgency(forScore: 0.99), .dueSoon)
        XCTAssertEqual(SuggestionEngine.urgency(forScore: 1.0), .due)
        XCTAssertEqual(SuggestionEngine.urgency(forScore: 1.49), .due)
        XCTAssertEqual(SuggestionEngine.urgency(forScore: 1.5), .overdue)
        XCTAssertEqual(SuggestionEngine.urgency(forScore: 10), .overdue)
    }

    func testFutureLastContactedCountsAsToday() {
        let p = Person(name: "Dad", cadenceDays: 7, lastContacted: cal.date(byAdding: .day, value: 2, to: now)!)
        XCTAssertTrue(SuggestionEngine.suggestions(people: [p], openers: [:], context: .init(), now: now, calendar: cal).isEmpty)
        let all = SuggestionEngine.suggestions(people: [p], openers: [:], context: .init(), now: now, calendar: cal, includeUpToDate: true)
        XCTAssertEqual(all.first?.daysSince, 0)
        XCTAssertEqual(all.first?.score, 0)
        XCTAssertEqual(all.first?.urgency, .upToDate)
        XCTAssertEqual(all.first?.sinceLabel, "Today")
    }

    func testDaysSinceAcrossAMidnightDSTChange() {
        // Chile: 2026-09-06 has no 00:00 (starts at 01:00), so the next day is only 23 hours after its start.
        var santiago = Calendar(identifier: .gregorian)
        santiago.timeZone = TimeZone(identifier: "America/Santiago")!
        let sunday = santiago.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12))!
        let monday = santiago.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 15))!
        let p = Person(name: "Mom", cadenceDays: 1, lastContacted: sunday)
        let s = SuggestionEngine.suggestions(people: [p], openers: [:], context: .init(), now: monday, calendar: santiago)
        XCTAssertEqual(s.first?.daysSince, 1)
        XCTAssertEqual(s.first?.urgency, .due)
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

    func testUnreadableFileIsBackedUpBeforeASaveCanOverwriteIt() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fh-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = Store(url: dir.appendingPathComponent("familyhub.json"))

        XCTAssertEqual(store.load(), AppData()) // no file yet: fresh data, no backup
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.unreadableBackupURL.path))

        let bad = Data(#"{"people":[{"name":42}]}"#.utf8)
        try bad.write(to: store.url)
        XCTAssertEqual(store.load(), AppData())
        XCTAssertEqual(try Data(contentsOf: store.unreadableBackupURL), bad)

        try store.save(AppData(people: [Person(name: "Mom")]))
        XCTAssertEqual(store.load().people.first?.name, "Mom")
        XCTAssertEqual(try Data(contentsOf: store.unreadableBackupURL), bad, "the backup is never overwritten")
    }

    func testUpdateKeepsAWriteFromAnotherStoreOnTheSameFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fh-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let app = Store(url: url)
        let widget = Store(url: url)
        // Whole seconds, because the file stores ISO 8601 dates without fractions.
        let when = Date(timeIntervalSince1970: 1_790_000_000)
        let mom = Person(name: "Mom", cadenceDays: 3, lastContacted: Date(timeIntervalSince1970: 0))
        try app.save(AppData(people: [mom]))
        let stale = app.load() // the app's in-memory copy

        try widget.update { _ = $0.markContacted(mom.id, at: when) } // the widget's ✓
        let saved = try app.update { $0.context.notes = "busy week" }

        XCTAssertEqual(stale.log.count, 0)
        XCTAssertEqual(saved.log.count, 1, "the widget's reach-out survives the app's later save")
        XCTAssertEqual(saved.people[0].lastContacted, when)
        XCTAssertEqual(saved.context.notes, "busy week")
        XCTAssertEqual(app.load(), saved)
    }

    func testUpdateReturnsWhatItSaved() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fh-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = Store(url: url)

        let saved = try store.update { $0.people.append(Person(name: "Jake")) } // no file yet: starts from AppData()
        XCTAssertEqual(saved.people.map(\.name), ["Jake"])
        XCTAssertEqual(store.load(), saved)
        XCTAssertEqual(Store(url: url).load(), saved)
    }

    func testUpdateClosureCanHandBackAResult() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fh-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = Store(url: url)
        let mom = Person(name: "Mom", cadenceDays: 3)
        try store.save(AppData(people: [mom]))

        var result: ReachOutResult?
        let saved = try store.update { result = $0.markContacted(mom.id) }
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.counted, true)
        XCTAssertEqual(saved.log.count, 1)
    }

    func testUpdateRefusesToReplaceAnUnreadableFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fh-\(UUID().uuidString).json")
        let store = Store(url: url)
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: store.unreadableBackupURL)
        }
        let bad = Data(#"{"people":[{"name":42}]}"#.utf8)
        try bad.write(to: url)

        XCTAssertThrowsError(try store.update { $0.people.append(Person(name: "Jake")) }) { error in
            XCTAssertTrue(error is Store.UnreadableFileError)
        }
        XCTAssertEqual(try Data(contentsOf: url), bad, "nothing was saved over the file")
        XCTAssertEqual(try Data(contentsOf: store.unreadableBackupURL), bad)
    }
}

/// Files written by older (or newer) builds must still load. JSON here uses the file's real format:
/// `Store.encoder`/`Store.decoder`, ISO 8601 dates without fractions.
final class CompatibilityTests: XCTestCase {
    let id = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00CF4FC964FF")!
    let when = ISO8601DateFormatter().date(from: "2026-09-22T15:00:00Z")!

    func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try Store.decoder.decode(type, from: Data(json.utf8))
    }

    // MARK: Person

    func testPersonWithOnlyIDAndNameGetsDefaults() throws {
        let p = try decode(Person.self, #"{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","name":"Mom"}"#)
        XCTAssertEqual(p, Person(id: id, name: "Mom"))
        XCTAssertEqual(p.cadenceDays, 7)
        XCTAssertEqual(p.relationship, "")
        XCTAssertNil(p.lastContacted)
        XCTAssertFalse(p.isFavorite)
    }

    func testPersonAsWrittenByTheFirstVersion() throws {
        let p = try decode(Person.self, #"{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","name":"Mom","relationship":"mother","phone":"555-0101","cadenceDays":3,"lastContacted":"2026-09-22T15:00:00Z","notes":"garden","isFavorite":true}"#)
        XCTAssertEqual(p, Person(id: id, name: "Mom", relationship: "mother", phone: "555-0101", cadenceDays: 3,
                                 lastContacted: when, notes: "garden", isFavorite: true))
    }

    func testPersonStillNeedsIDAndName() {
        XCTAssertThrowsError(try decode(Person.self, #"{"name":"Mom"}"#))
        XCTAssertThrowsError(try decode(Person.self, #"{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF"}"#))
    }

    // MARK: LifeContext

    func testLifeContextWithMissingKeysGetsDefaults() throws {
        XCTAssertEqual(try decode(LifeContext.self, "{}"), LifeContext())
        XCTAssertEqual(try decode(LifeContext.self, #"{"projects":["Family Hub"]}"#), LifeContext(projects: ["Family Hub"]))
    }

    // MARK: Opener

    func testOpenerWithOnlyPersonAndTextIsBuiltInAndStale() throws {
        let o = try decode(Opener.self, #"{"personID":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","text":"hi"}"#)
        XCTAssertEqual(o.personID, id)
        XCTAssertEqual(o.text, "hi")
        XCTAssertFalse(o.isAI)
        XCTAssertEqual(o.createdAt, .distantPast, "unknown age counts as stale, so it gets rewritten")
    }

    func testOpenerAsWrittenByTheFirstVersion() throws {
        let o = try decode(Opener.self, #"{"personID":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","text":"hi","isAI":true,"createdAt":"2026-09-22T15:00:00Z"}"#)
        XCTAssertEqual(o, Opener(personID: id, text: "hi", isAI: true, createdAt: when))
    }

    // MARK: ReachOut

    func testReachOutWithOnlyPersonAndDateGetsDefaults() throws {
        let r = try decode(ReachOut.self, #"{"personID":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","date":"2026-09-22T15:00:00Z"}"#)
        XCTAssertEqual(r, ReachOut(personID: id, date: when, kind: .late, points: 0))
    }

    func testReachOutAsWrittenByTheFirstVersion() throws {
        let r = try decode(ReachOut.self, #"{"personID":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","date":"2026-09-22T15:00:00Z","kind":"reconnect","points":25}"#)
        XCTAssertEqual(r, ReachOut(personID: id, date: when, kind: .reconnect, points: 25))
    }

    func testUnknownReachOutKindDoesNotFailTheFile() throws {
        let json = #"{"log":[{"personID":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","date":"2026-09-22T15:00:00Z","kind":"superStreak","points":40}]}"#
        let data = try decode(AppData.self, json)
        XCTAssertEqual(data.log.first?.kind, .late)
        XCTAssertEqual(data.xp, 40, "stored points are kept")
    }

    // MARK: Preferences

    func testPreferencesWithMissingKeysGetDefaults() throws {
        XCTAssertEqual(try decode(Preferences.self, "{}"), Preferences())
        XCTAssertEqual(try decode(Preferences.self, #"{"dailyGoal":2}"#), Preferences(dailyGoal: 2))
    }

    func testPreferencesAsWrittenByTheFirstVersion() throws {
        let p = try decode(Preferences.self, #"{"dailyGoal":2,"remindersOn":true,"reminderHour":20,"reminderMinute":30,"theme":"ocean"}"#)
        XCTAssertEqual(p, Preferences(dailyGoal: 2, remindersOn: true, reminderHour: 20, reminderMinute: 30, theme: .ocean))
    }

    func testUnknownThemeFallsBackToTheDefault() throws {
        let p = try decode(Preferences.self, #"{"dailyGoal":3,"theme":"neon"}"#)
        XCTAssertEqual(p.theme, .coral)
        XCTAssertEqual(p.dailyGoal, 3)
    }

    // MARK: Whole file

    func testFileFromTheFirstVersionLoadsThroughTheStore() throws {
        // The shape commit 1f486be wrote: no log, badges or preferences yet.
        let old = #"{"people":[{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","name":"Mom","relationship":"mother","phone":"","cadenceDays":3,"lastContacted":"2026-09-22T15:00:00Z","notes":"","isFavorite":false}],"openers":[],"context":{"projects":["x"],"notes":"","upcomingEvents":[]},"openersRefreshedAt":"2026-09-22T15:00:00Z","openersInputHash":"abc"}"#
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fh-\(UUID().uuidString).json")
        let store = Store(url: url)
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: store.unreadableBackupURL)
        }
        try Data(old.utf8).write(to: url)

        let data = store.load()
        XCTAssertEqual(data.people, [Person(id: id, name: "Mom", relationship: "mother", cadenceDays: 3, lastContacted: when)])
        XCTAssertEqual(data.context.projects, ["x"])
        XCTAssertEqual(data.openersRefreshedAt, when)
        XCTAssertEqual(data.openersInputHash, "abc")
        XCTAssertTrue(data.log.isEmpty)
        XCTAssertEqual(data.preferences, Preferences())
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.unreadableBackupURL.path), "the file was readable")
    }

    func testRoundTripKeepsEveryField() throws {
        let p = Person(id: id, name: "Jake Smith", relationship: "brother", phone: "555-0102", cadenceDays: 5,
                       lastContacted: when, notes: "the Denver trip", snoozedUntil: when.addingTimeInterval(86400),
                       isFavorite: true)
        let original = AppData(
            people: [p],
            openers: [p.id: Opener(personID: p.id, text: "yo", isAI: true, createdAt: when)],
            context: LifeContext(projects: ["Family Hub"], notes: "busy week", upcomingEvents: ["Dentist"]),
            openersRefreshedAt: when,
            openersInputHash: "abc",
            log: [
                ReachOut(personID: p.id, date: when.addingTimeInterval(-3 * 86400), kind: .first, points: 20),
                ReachOut(personID: p.id, date: when.addingTimeInterval(-2 * 86400), kind: .onTime, points: 15),
                ReachOut(personID: p.id, date: when.addingTimeInterval(-86400), kind: .late, points: 10),
                ReachOut(personID: p.id, date: when, kind: .reconnect, points: 25),
            ],
            badges: [Badge.firstHello.rawValue: when],
            preferences: Preferences(dailyGoal: 2, remindersOn: true, reminderHour: 20, reminderMinute: 30, theme: .grape)
        )
        let encoded = try Store.encoder.encode(original)
        XCTAssertEqual(try Store.decoder.decode(AppData.self, from: encoded), original)

        // The file format itself is unchanged: a person is still written with exactly these keys.
        let personJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: Store.encoder.encode(p)) as? [String: Any])
        XCTAssertEqual(Set(personJSON.keys), ["id", "name", "relationship", "phone", "cadenceDays", "lastContacted",
                                              "notes", "snoozedUntil", "isFavorite"])
        XCTAssertEqual(personJSON["lastContacted"] as? String, "2026-09-22T15:00:00Z")
    }
}

final class PersonMergeTests: XCTestCase {
    let before = Date(timeIntervalSince1970: 1_780_000_000)
    let widgetTick = Date(timeIntervalSince1970: 1_790_000_000)

    /// The person when the edit sheet opened: snoozed, last texted a while ago.
    var original: Person {
        Person(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Mom", cadenceDays: 3,
               lastContacted: before, snoozedUntil: .distantFuture)
    }

    /// What's on disk after the widget's ✓ (same as `markContacted`: new date, snooze cleared).
    var latest: Person {
        var p = original
        p.lastContacted = widgetTick
        p.snoozedUntil = nil
        return p
    }

    func testWidgetTickSurvivesAnEditThatOnlyChangedTheName() {
        var edited = original
        edited.name = "Mama"
        let merged = latest.applyingEdits(from: original, to: edited)
        XCTAssertEqual(merged.name, "Mama")
        XCTAssertEqual(merged.lastContacted, widgetTick)
        XCTAssertNil(merged.snoozedUntil)
        XCTAssertEqual(merged.id, original.id)
    }

    func testLastContactedChangedInTheEditorWins() {
        let picked = Date(timeIntervalSince1970: 1_785_000_000)
        var edited = original
        edited.lastContacted = picked
        XCTAssertEqual(latest.applyingEdits(from: original, to: edited).lastContacted, picked)
    }

    func testNothingEditedReturnsLatestUnchanged() {
        XCTAssertEqual(latest.applyingEdits(from: original, to: original), latest)
    }

    func testFieldChangedOnBothSidesTakesTheEdit() {
        var newer = latest
        newer.isFavorite = true
        newer.notes = "from elsewhere"
        var edited = original
        edited.notes = "the Denver trip"
        let merged = newer.applyingEdits(from: original, to: edited)
        XCTAssertEqual(merged.notes, "the Denver trip")
        XCTAssertTrue(merged.isFavorite, "a field the user didn't touch keeps its latest value")
        XCTAssertEqual(merged.lastContacted, widgetTick)
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
