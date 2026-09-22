import Foundation

// MARK: - Log

/// One logged reach-out. Points are fixed when it's logged, because "on time" depends on the state at that moment.
public struct ReachOut: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case first      // first time you've texted this person in Family Hub
        case onTime     // before they were due
        case late       // after they were due
        case reconnect  // after a long gap (30+ days)
    }

    public var personID: UUID
    public var date: Date
    public var kind: Kind
    public var points: Int

    public init(personID: UUID, date: Date, kind: Kind, points: Int) {
        self.personID = personID
        self.date = date
        self.kind = kind
        self.points = points
    }
}

// MARK: - Preferences

public enum Theme: String, Codable, CaseIterable, Sendable {
    case coral, ocean, forest, grape, sunset, midnight

    public var displayName: String { rawValue.capitalized }

    /// Gradient start/end as 0xRRGGBB. The first is also the accent color.
    public var colors: (UInt32, UInt32) {
        switch self {
        case .coral: return (0xEC486E, 0xFF8F73)
        case .ocean: return (0x1F7AE0, 0x35C6D6)
        case .forest: return (0x2E9D5B, 0x9BCB4B)
        case .grape: return (0x7B4BD6, 0xD65BB6)
        case .sunset: return (0xF06A2A, 0xF7B733)
        case .midnight: return (0x3A4A8C, 0x14162B)
        }
    }
}

public struct Preferences: Codable, Hashable, Sendable {
    /// Reach out to this many people a day to extend your streak.
    public var dailyGoal: Int
    public var remindersOn: Bool
    public var reminderHour: Int
    public var reminderMinute: Int
    public var theme: Theme

    public init(dailyGoal: Int = 1, remindersOn: Bool = false, reminderHour: Int = 18, reminderMinute: Int = 0, theme: Theme = .coral) {
        self.dailyGoal = max(1, dailyGoal)
        self.remindersOn = remindersOn
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.theme = theme
    }
}

// MARK: - Badges

public enum Badge: String, Codable, CaseIterable, Sendable {
    case firstHello, threeDayStreak, weekStreak, monthStreak, fiveFriends, reconnector, allCaughtUp, tenReachOuts, fiftyReachOuts

    public var title: String {
        switch self {
        case .firstHello: return "First Hello"
        case .threeDayStreak: return "On a Roll"
        case .weekStreak: return "Week Warrior"
        case .monthStreak: return "Unstoppable"
        case .fiveFriends: return "Circle of Five"
        case .reconnector: return "Reconnector"
        case .allCaughtUp: return "All Caught Up"
        case .tenReachOuts: return "Regular"
        case .fiftyReachOuts: return "Social Star"
        }
    }

    public var detail: String {
        switch self {
        case .firstHello: return "Sent your first text from Family Hub"
        case .threeDayStreak: return "3-day streak"
        case .weekStreak: return "7-day streak"
        case .monthStreak: return "30-day streak"
        case .fiveFriends: return "Texted 5 different people"
        case .reconnector: return "Reached out after 30+ days apart"
        case .allCaughtUp: return "Nobody left waiting (3+ people)"
        case .tenReachOuts: return "10 texts sent"
        case .fiftyReachOuts: return "50 texts sent"
        }
    }

    /// SF Symbol name.
    public var symbol: String {
        switch self {
        case .firstHello: return "hand.wave.fill"
        case .threeDayStreak: return "flame.fill"
        case .weekStreak: return "flame.circle.fill"
        case .monthStreak: return "crown.fill"
        case .fiveFriends: return "person.3.fill"
        case .reconnector: return "arrow.triangle.2.circlepath"
        case .allCaughtUp: return "checkmark.seal.fill"
        case .tenReachOuts: return "message.fill"
        case .fiftyReachOuts: return "star.fill"
        }
    }
}

// MARK: - Results

public struct StreakStatus: Equatable, Sendable {
    public var current: Int
    public var longest: Int
    /// Freezes banked (max 2). One is earned every 7 streak days and spent automatically on a missed day.
    public var freezes: Int
    public var doneToday: Int
    public var goal: Int
    /// Days a freeze saved the streak.
    public var frozenDays: [Date]

    public init(current: Int, longest: Int, freezes: Int, doneToday: Int, goal: Int, frozenDays: [Date]) {
        self.current = current
        self.longest = longest
        self.freezes = freezes
        self.doneToday = doneToday
        self.goal = goal
        self.frozenDays = frozenDays
    }

    public static let none = StreakStatus(current: 0, longest: 0, freezes: 0, doneToday: 0, goal: 1, frozenDays: [])

        public var goalMetToday: Bool { doneToday >= goal }
    /// A streak is going but today's goal isn't met yet.
    public var atRisk: Bool { current > 0 && !goalMetToday }
}

public struct Level: Equatable, Sendable {
    public var number: Int
    public var title: String
    public var xp: Int
    /// XP where this level started and where the next one starts.
    public var floor: Int
    public var next: Int

    public var progress: Double { next > floor ? Double(xp - floor) / Double(next - floor) : 1 }
    public var toNext: Int { max(0, next - xp) }
}

public struct DayCount: Identifiable, Hashable, Sendable {
    public var day: Date
    public var count: Int
    public var id: Date { day }
}

/// What happened when you logged a reach-out: drives the celebration screen.
public struct ReachOutResult: Equatable, Sendable {
    public var personID: UUID
    public var kind: ReachOut.Kind
    public var points: Int
    public var streak: StreakStatus
    public var level: Level
    public var leveledUp: Bool
    public var newBadges: [Badge]
    /// False if they'd already been logged today (no double points).
    public var counted: Bool
}

// MARK: - Engine

public enum Engagement {
    public static let basePoints = 10
    public static let onTimeBonus = 5
    public static let reconnectBonus = 15
    public static let firstBonus = 10
    public static let reconnectDays = 30
    public static let maxFreezes = 2

    static let levelFloors = [0, 50, 125, 250, 450, 700, 1000, 1400, 1900, 2500]
    static let levelTitles = [
        "Newcomer", "Pen Pal", "Check-in Champ", "Good Friend", "Connector",
        "Heart of the Group", "Family Glue", "Social Butterfly", "Legend", "Hall of Famer",
    ]
    static let pointsPerLevelAfterMax = 700

    /// Kind and points for reaching out to `person` now, given when you last did.
    public static func score(for person: Person, now: Date, calendar: Calendar = .current) -> (ReachOut.Kind, Int) {
        guard let last = person.lastContacted else { return (.first, basePoints + firstBonus) }
        let days = daysBetween(last, now, calendar)
        if days >= reconnectDays { return (.reconnect, basePoints + reconnectBonus) }
        if days <= person.cadenceDays { return (.onTime, basePoints + onTimeBonus) }
        return (.late, basePoints)
    }

    public static func streak(log: [ReachOut], goal: Int, now: Date = .now, calendar: Calendar = .current) -> StreakStatus {
        let goal = max(1, goal)
        var perDay: [Date: Int] = [:]
        for r in log { perDay[calendar.startOfDay(for: r.date), default: 0] += 1 }
        let today = calendar.startOfDay(for: now)
        var status = StreakStatus(current: 0, longest: 0, freezes: 0, doneToday: perDay[today] ?? 0, goal: goal, frozenDays: [])
        guard var day = perDay.keys.min(), day <= today else { return status }

        while day <= today {
            if (perDay[day] ?? 0) >= goal {
                status.current += 1
                status.longest = max(status.longest, status.current)
                if status.current % 7 == 0 { status.freezes = min(maxFreezes, status.freezes + 1) }
            } else if day < today {
                if status.current > 0, status.freezes > 0 {
                    status.freezes -= 1
                    status.frozenDays.append(day)
                } else {
                    status.current = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return status
    }

    /// Consecutive on-time check-ins with one person (a day of grace), 0 once they're overdue.
    public static func personStreak(_ person: Person, log: [ReachOut], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(log.filter { $0.personID == person.id }.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard let lastDay = days.last else { return 0 }
        let allowed = person.cadenceDays + 1
        if daysBetween(lastDay, now, calendar) > allowed { return 0 }
        var count = 0
        var prev: Date?
        for d in days {
            if let p = prev, daysBetween(p, d, calendar) > allowed { count = 1 } else { count += 1 }
            prev = d
        }
        return count
    }

    public static func level(xp: Int) -> Level {
        if let i = levelFloors.lastIndex(where: { $0 <= xp }), i < levelFloors.count - 1 {
            return Level(number: i + 1, title: levelTitles[i], xp: xp, floor: levelFloors[i], next: levelFloors[i + 1])
        }
        let top = levelFloors.last!
        let extra = (xp - top) / pointsPerLevelAfterMax
        let floor = top + extra * pointsPerLevelAfterMax
        return Level(number: levelFloors.count + extra, title: levelTitles.last!, xp: xp, floor: floor, next: floor + pointsPerLevelAfterMax)
    }

    /// Reach-outs per day for the last `days` days, oldest first (for the weekly chart).
    public static func activity(log: [ReachOut], days: Int = 7, now: Date = .now, calendar: Calendar = .current) -> [DayCount] {
        let today = calendar.startOfDay(for: now)
        var perDay: [Date: Int] = [:]
        for r in log { perDay[calendar.startOfDay(for: r.date), default: 0] += 1 }
        return (0..<days).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { DayCount(day: $0, count: perDay[$0] ?? 0) }
        }
    }

    static func earnedBadges(_ data: AppData, now: Date, calendar: Calendar) -> Set<Badge> {
        var earned = Set<Badge>()
        let log = data.log
        if !log.isEmpty { earned.insert(.firstHello) }
        if log.count >= 10 { earned.insert(.tenReachOuts) }
        if log.count >= 50 { earned.insert(.fiftyReachOuts) }
        if Set(log.map(\.personID)).count >= 5 { earned.insert(.fiveFriends) }
        if log.contains(where: { $0.kind == .reconnect }) { earned.insert(.reconnector) }
        let longest = streak(log: log, goal: data.preferences.dailyGoal, now: now, calendar: calendar).longest
        if longest >= 3 { earned.insert(.threeDayStreak) }
        if longest >= 7 { earned.insert(.weekStreak) }
        if longest >= 30 { earned.insert(.monthStreak) }
        if data.people.count >= 3, data.suggestions(now: now).isEmpty { earned.insert(.allCaughtUp) }
        return earned
    }

    /// The text for tonight's reminder notification, or nil when there's nothing worth nudging about.
    public static func reminder(for data: AppData, now: Date = .now) -> (title: String, body: String)? {
        let s = data.streakStatus(now: now)
        guard let top = data.suggestions(now: now).first else { return nil }
        let who = "\(top.person.firstName) would love to hear from you"
        if s.atRisk {
            return ("🔥 Keep your \(s.current)-day streak going", "\(who) (\(top.sinceLabel.lowercased())).")
        }
        if s.goalMetToday { return nil }
        return ("💬 Time to say hi", "\(who). \"\(top.opener.text)\"")
    }

    static func daysBetween(_ a: Date, _ b: Date, _ calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0
    }
}

// MARK: - AppData integration

extension AppData {
    public var xp: Int { log.reduce(0) { $0 + $1.points } }
    public var level: Level { Engagement.level(xp: xp) }

    public func streakStatus(now: Date = .now, calendar: Calendar = .current) -> StreakStatus {
        Engagement.streak(log: log, goal: preferences.dailyGoal, now: now, calendar: calendar)
    }

    public func personStreak(_ person: Person, now: Date = .now, calendar: Calendar = .current) -> Int {
        Engagement.personStreak(person, log: log, now: now, calendar: calendar)
    }

    /// Log that you reached out: resets their clock, awards points (once per person per day) and badges.
    @discardableResult
    public mutating func markContacted(_ id: UUID, at date: Date = .now, calendar: Calendar = .current) -> ReachOutResult? {
        guard let i = people.firstIndex(where: { $0.id == id }) else { return nil }
        let levelBefore = level
        let alreadyToday = log.contains { $0.personID == id && calendar.isDate($0.date, inSameDayAs: date) }
        let (kind, points) = Engagement.score(for: people[i], now: date, calendar: calendar)

        people[i].lastContacted = date
        people[i].snoozedUntil = nil
        openers[id] = nil
        if !alreadyToday {
            log.append(ReachOut(personID: id, date: date, kind: kind, points: points))
        }

        let earned = Engagement.earnedBadges(self, now: date, calendar: calendar)
        let fresh = Badge.allCases.filter { earned.contains($0) && badges[$0.rawValue] == nil }
        for b in fresh { badges[b.rawValue] = date }

        let levelAfter = level
        return ReachOutResult(
            personID: id,
            kind: kind,
            points: alreadyToday ? 0 : points,
            streak: streakStatus(now: date, calendar: calendar),
            level: levelAfter,
            leveledUp: levelAfter.number > levelBefore.number,
            newBadges: fresh,
            counted: !alreadyToday
        )
    }
}

extension ReachOutResult: Identifiable {
    public var id: String { "\(personID.uuidString)-\(points)-\(streak.current)" }
}
