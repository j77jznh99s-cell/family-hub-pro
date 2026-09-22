import Foundation

/// Someone you want to stay in touch with.
public struct Person: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    /// "Mom", "brother", "friend from work" — used to pick a tone for openers.
    public var relationship: String
    public var phone: String
    /// How often you'd like to reach out, in days.
    public var cadenceDays: Int
    /// Last time you texted them (nil = never logged).
    public var lastContacted: Date?
    /// Anything worth remembering: their job hunt, their kid's soccer, the trip they're planning.
    public var notes: String
    /// Temporarily hide from suggestions until this date (e.g. "I'm seeing them this weekend").
    public var snoozedUntil: Date?
    /// Pinned people are ranked above everyone else at the same urgency level.
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        relationship: String = "",
        phone: String = "",
        cadenceDays: Int = 7,
        lastContacted: Date? = nil,
        notes: String = "",
        snoozedUntil: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.phone = phone
        self.cadenceDays = max(1, cadenceDays)
        self.lastContacted = lastContacted
        self.notes = notes
        self.snoozedUntil = snoozedUntil
        self.isFavorite = isFavorite
    }

    public var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

/// What's going on in your life, so openers can be about something real.
public struct LifeContext: Codable, Hashable, Sendable {
    /// Projects you're working on ("building the Family Hub app", "studying for my CDL").
    public var projects: [String]
    /// Free-form notes about your week ("dentist Thursday", "tired from double shift").
    public var notes: String
    /// Upcoming calendar items pulled from the device calendar (titles only, next 7 days).
    public var upcomingEvents: [String]

    public init(projects: [String] = [], notes: String = "", upcomingEvents: [String] = []) {
        self.projects = projects
        self.notes = notes
        self.upcomingEvents = upcomingEvents
    }

    public var isEmpty: Bool {
        projects.isEmpty && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && upcomingEvents.isEmpty
    }
}

/// A conversation starter for one person.
public struct Opener: Codable, Hashable, Sendable {
    public var personID: UUID
    public var text: String
    /// True when Claude wrote it; false for the built-in offline fallback.
    public var isAI: Bool
    public var createdAt: Date

    public init(personID: UUID, text: String, isAI: Bool, createdAt: Date = .now) {
        self.personID = personID
        self.text = text
        self.isAI = isAI
        self.createdAt = createdAt
    }
}

public enum Urgency: Int, Codable, Comparable, Sendable {
    case upToDate = 0
    case dueSoon = 1
    case due = 2
    case overdue = 3

    public static func < (lhs: Urgency, rhs: Urgency) -> Bool { lhs.rawValue < rhs.rawValue }

    public var label: String {
        switch self {
        case .upToDate: return "All caught up"
        case .dueSoon: return "Due soon"
        case .due: return "Time to text"
        case .overdue: return "Overdue"
        }
    }
}

/// One ranked "you should text X" suggestion.
public struct Suggestion: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { person.id }
    public var person: Person
    /// Whole days since last contact (nil if never).
    public var daysSince: Int?
    public var urgency: Urgency
    /// daysSince / cadence — >1 means overdue. Never-contacted people count as 1.5.
    public var score: Double
    public var opener: Opener

    public init(person: Person, daysSince: Int?, urgency: Urgency, score: Double, opener: Opener) {
        self.person = person
        self.daysSince = daysSince
        self.urgency = urgency
        self.score = score
        self.opener = opener
    }

    /// Short phrase for tight spaces: "12 days", "Never texted".
    public var sinceLabel: String {
        guard let d = daysSince else { return "Not texted yet" }
        switch d {
        case 0: return "Today"
        case 1: return "1 day"
        default: return "\(d) days"
        }
    }
}
