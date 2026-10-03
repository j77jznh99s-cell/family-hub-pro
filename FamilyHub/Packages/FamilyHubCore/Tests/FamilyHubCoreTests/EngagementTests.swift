import XCTest
@testable import FamilyHubCore

final class EngagementTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let now = ISO8601DateFormatter().date(from: "2026-09-22T15:00:00Z")!
    let mom = Person(name: "Mom", cadenceDays: 3)

    func day(_ offset: Int, hour: Int = 12) -> Date {
        cal.date(byAdding: .hour, value: hour - 15, to: cal.date(byAdding: .day, value: offset, to: now)!)!
    }

    func reach(_ offset: Int, _ person: Person? = nil) -> ReachOut {
        ReachOut(personID: (person ?? mom).id, date: day(offset), kind: .onTime, points: 15)
    }

    // MARK: Streaks

    func testStreakCountsConsecutiveDaysIncludingToday() {
        let s = Engagement.streak(log: [reach(-2), reach(-1), reach(0)], goal: 1, now: now, calendar: cal)
        XCTAssertEqual(s.current, 3)
        XCTAssertEqual(s.longest, 3)
        XCTAssertTrue(s.goalMetToday)
        XCTAssertFalse(s.atRisk)
    }

    func testStreakSurvivesUntilTodayEndsButIsAtRisk() {
        let s = Engagement.streak(log: [reach(-2), reach(-1)], goal: 1, now: now, calendar: cal)
        XCTAssertEqual(s.current, 2)
        XCTAssertTrue(s.atRisk)
    }

    func testMissedDayWithoutFreezeResetsStreak() {
        let s = Engagement.streak(log: [reach(-4), reach(-3), reach(-1)], goal: 1, now: now, calendar: cal)
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.longest, 2)
    }

    func testSevenDayStreakEarnsAFreezeThatSavesAMissedDay() {
        // Days -9...-3 (7 days) earn a freeze, -2 is missed, -1 and today continue.
        let log = (-9...(-3)).map { reach($0) } + [reach(-1), reach(0)]
        let s = Engagement.streak(log: log, goal: 1, now: now, calendar: cal)
        XCTAssertEqual(s.current, 9)
        XCTAssertEqual(s.freezes, 0)
        XCTAssertEqual(s.frozenDays, [cal.startOfDay(for: day(-2))])
    }

    func testDailyGoalOfTwoNeedsTwoReachOuts() {
        let jake = Person(name: "Jake")
        let s = Engagement.streak(log: [reach(-1), reach(-1, jake), reach(0)], goal: 2, now: now, calendar: cal)
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.doneToday, 1)
        XCTAssertTrue(s.atRisk)
    }

    func testEmptyLogHasNoStreak() {
        let s = Engagement.streak(log: [], goal: 1, now: now, calendar: cal)
        XCTAssertEqual(s.current, 0)
        XCTAssertFalse(s.atRisk)
    }

    func testFreezesCapAtTwo() {
        // 21 days earns a freeze at day 7, 14 and 21, but only two can be banked.
        let s = Engagement.streak(log: (-20...0).map { reach($0) }, goal: 1, now: now, calendar: cal)
        XCTAssertEqual(s.current, 21)
        XCTAssertEqual(s.freezes, 2)
    }

    func testTwoBankedFreezesSaveTwoMissedDaysAndTheThirdResets() {
        let run = (-24...(-4)).map { reach($0) } // 21 days → 2 freezes (capped)
        // Miss -3 and -2, then keep going: both freezes are spent and the streak survives.
        let saved = Engagement.streak(log: run + [reach(-1), reach(0)], goal: 1, now: now, calendar: cal)
        XCTAssertEqual(saved.current, 23)
        XCTAssertEqual(saved.longest, 23)
        XCTAssertEqual(saved.freezes, 0)
        XCTAssertEqual(saved.frozenDays, [cal.startOfDay(for: day(-3)), cal.startOfDay(for: day(-2))])

        // Miss -3, -2 and -1: a third freeze would have been needed, so the streak restarts today.
        let lost = Engagement.streak(log: run + [reach(0)], goal: 1, now: now, calendar: cal)
        XCTAssertEqual(lost.current, 1)
        XCTAssertEqual(lost.longest, 21)
        XCTAssertEqual(lost.freezes, 0)
    }

    // MARK: DST (Chile starts DST at midnight: 2026-09-06 has no 00:00 and starts at 01:00)

    let santiago: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Santiago")!
        return c
    }()

    func september(_ day: Int, hour: Int = 12) -> Date {
        santiago.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    func testStreakSurvivesAMidnightDSTChange() {
        let log = (1...10).map { ReachOut(personID: mom.id, date: september($0), kind: .onTime, points: 15) }
        let s = Engagement.streak(log: log, goal: 1, now: september(10, hour: 15), calendar: santiago)
        XCTAssertEqual(s.current, 10)
        XCTAssertEqual(s.longest, 10)
        XCTAssertEqual(s.freezes, 1)
        XCTAssertTrue(s.frozenDays.isEmpty)
    }

    func testActivityOnTheDayDSTStartsAtOneAM() {
        let log = [5, 6].map { ReachOut(personID: mom.id, date: september($0), kind: .onTime, points: 15) }
        let a = Engagement.activity(log: log, days: 3, now: september(6, hour: 15), calendar: santiago)
        XCTAssertEqual(a.map(\.count), [0, 1, 1])
    }

    // MARK: Per-person streaks

    func testPersonStreakCountsOnTimeCheckInsAndDiesWhenOverdue() {
        let log = [reach(-12), reach(-8), reach(-5), reach(-2)] // gaps: 4, 3, 3 with cadence 3 (+1 grace)
        XCTAssertEqual(Engagement.personStreak(mom, log: log, now: now, calendar: cal), 4)
        let later = cal.date(byAdding: .day, value: 5, to: now)!
        XCTAssertEqual(Engagement.personStreak(mom, log: log, now: later, calendar: cal), 0)
    }

    func testPersonStreakRestartsAfterALongGap() {
        let log = [reach(-20), reach(-10), reach(-7)]
        XCTAssertEqual(Engagement.personStreak(mom, log: log, now: now, calendar: cal), 0) // 7 days since, cadence 3
        XCTAssertEqual(Engagement.personStreak(mom, log: log, now: day(-6), calendar: cal), 2)
    }

    // MARK: Points, levels, badges

    func testScoringKinds() {
        var p = mom
        XCTAssertEqual(Engagement.score(for: p, now: now, calendar: cal).0, .first)
        p.lastContacted = day(-2)
        XCTAssertEqual(Engagement.score(for: p, now: now, calendar: cal).0, .onTime)
        XCTAssertEqual(Engagement.score(for: p, now: now, calendar: cal).1, 15)
        p.lastContacted = day(-10)
        XCTAssertEqual(Engagement.score(for: p, now: now, calendar: cal).0, .late)
        p.lastContacted = day(-45)
        XCTAssertEqual(Engagement.score(for: p, now: now, calendar: cal).0, .reconnect)
    }

    func testLevels() {
        XCTAssertEqual(Engagement.level(xp: 0).number, 1)
        XCTAssertEqual(Engagement.level(xp: 0).title, "Newcomer")
        XCTAssertEqual(Engagement.level(xp: 60).number, 2)
        XCTAssertEqual(Engagement.level(xp: 60).toNext, 65)
        XCTAssertEqual(Engagement.level(xp: 2500).number, 10)
        XCTAssertEqual(Engagement.level(xp: 3300).number, 11)
        XCTAssertEqual(Engagement.level(xp: 3300).title, "Hall of Famer")
    }

    func testLevelBoundariesAndLargeXP() {
        XCTAssertEqual(Engagement.level(xp: 49).number, 1)
        XCTAssertEqual(Engagement.level(xp: 49).toNext, 1)
        XCTAssertEqual(Engagement.level(xp: 50).number, 2)
        XCTAssertEqual(Engagement.level(xp: 50).floor, 50)
        XCTAssertEqual(Engagement.level(xp: 50).next, 125)
        XCTAssertEqual(Engagement.level(xp: 3199).number, 10)
        XCTAssertEqual(Engagement.level(xp: 3199).toNext, 1)
        let big = Engagement.level(xp: 1_000_000) // 2500 + 1425 × 700
        XCTAssertEqual(big.number, 1435)
        XCTAssertEqual(big.floor, 1_000_000)
        XCTAssertEqual(big.next, 1_000_700)
        XCTAssertEqual(big.progress, 0)
        XCTAssertEqual(big.title, "Hall of Famer")
    }

    func testNegativeXPIsLevelOne() {
        let l = Engagement.level(xp: -10)
        XCTAssertEqual(l.number, 1)
        XCTAssertEqual(l.title, "Newcomer")
        XCTAssertEqual(l.progress, 0)
    }

    func testMarkContactedAwardsPointsOncePerDayAndBadges() {
        var data = AppData(people: [
            Person(name: "Mom", cadenceDays: 3, lastContacted: day(-40)),
            Person(name: "Jake", cadenceDays: 7, lastContacted: day(-1)),
            Person(name: "Ana", cadenceDays: 7, lastContacted: day(-2)),
        ])
        let id = data.people[0].id
        let r1 = data.markContacted(id, at: now, calendar: cal)!
        XCTAssertEqual(r1.kind, .reconnect)
        XCTAssertEqual(r1.points, 25)
        XCTAssertTrue(r1.counted)
        XCTAssertEqual(r1.streak.current, 1)
        XCTAssertEqual(Set(r1.newBadges), [.firstHello, .reconnector, .allCaughtUp])

        let r2 = data.markContacted(id, at: now.addingTimeInterval(600), calendar: cal)!
        XCTAssertFalse(r2.counted)
        XCTAssertEqual(r2.points, 0)
        XCTAssertTrue(r2.newBadges.isEmpty)
        XCTAssertEqual(data.log.count, 1)
        XCTAssertEqual(data.xp, 25)
    }

    func testLevelUpIsReported() {
        var data = AppData(people: [Person(name: "Mom")])
        data.log = [ReachOut(personID: UUID(), date: day(-1), kind: .late, points: 45)]
        let r = data.markContacted(data.people[0].id, at: now, calendar: cal)!
        XCTAssertTrue(r.leveledUp)
        XCTAssertEqual(r.level.number, 2)
    }

    func testReminderText() {
        var data = AppData(people: [Person(name: "Mom Smith", cadenceDays: 3, lastContacted: day(-9))])
        XCTAssertEqual(Engagement.reminder(for: data, now: now)?.title, "💬 Time to say hi")
        data.log = [reach(-1)]
        let r = Engagement.reminder(for: data, now: now)
        XCTAssertEqual(r?.title, "🔥 Keep your 1-day streak going")
        XCTAssertEqual(r?.body, "Mom would love to hear from you (9 days).")
    }

    func testActivityIsOldestFirst() {
        let a = Engagement.activity(log: [reach(0), reach(0), reach(-6)], days: 7, now: now, calendar: cal)
        XCTAssertEqual(a.map(\.count), [1, 0, 0, 0, 0, 0, 2])
    }

    // MARK: Compatibility

    func testDecodesFilesFromBeforeEngagement() throws {
        let old = #"{"people":[{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","name":"Mom","relationship":"","phone":"","cadenceDays":3,"notes":"","isFavorite":true}],"openers":[],"context":{"projects":["x"],"notes":"","upcomingEvents":[]}}"#
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        let data = try d.decode(AppData.self, from: Data(old.utf8))
        XCTAssertEqual(data.people.first?.name, "Mom")
        XCTAssertEqual(data.context.projects, ["x"])
        XCTAssertTrue(data.log.isEmpty)
        XCTAssertEqual(data.preferences, Preferences())
    }

    func testPhotoFilesRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fh-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = Store(url: dir.appendingPathComponent("familyhub.json"))
        let id = UUID()
        XCTAssertFalse(store.hasPhoto(for: id))
        try store.writeImage(Data([1, 2, 3]), to: store.photoURL(for: id))
        XCTAssertTrue(store.hasPhoto(for: id))
        try store.writeImage(nil, to: store.photoURL(for: id))
        XCTAssertFalse(store.hasPhoto(for: id))
    }
}
