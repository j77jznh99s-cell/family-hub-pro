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

    /// 3-way merge for saving an edit made on a copy that may have gone stale (e.g. a widget ✓ landed while the
    /// edit sheet was open). Call on the latest stored person: each field the user changed (`edited` differs from
    /// `original`) wins, every other field keeps its latest value. `id` never changes.
    /// When you add a stored field to `Person`, add it here too, or edits to it will be dropped.
    public func applyingEdits(from original: Person, to edited: Person) -> Person {
        var merged = self
        func take<Value: Equatable>(_ field: WritableKeyPath<Person, Value>) {
            if edited[keyPath: field] != original[keyPath: field] { merged[keyPath: field] = edited[keyPath: field] }
        }
        take(\.name)
        take(\.relationship)
        take(\.phone)
        take(\.cadenceDays)
        take(\.lastContacted)
        take(\.notes)
        take(\.snoozedUntil)
        take(\.isFavorite)
        return merged
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

/// A recorded catch-up conversation, summarized by Claude: a one-sentence recap, a short note worth
/// keeping on that person's profile, and a checklist of anything you said you'd follow up on.
public struct CatchUpNote: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// nil until it's assigned to someone — the general "record a catch-up" entry point starts unassigned.
    public var personID: UUID?
    public var transcript: String
    public var summary: String
    public var suggestedNote: String
    public var actionItems: [String]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        personID: UUID? = nil,
        transcript: String = "",
        summary: String = "",
        suggestedNote: String = "",
        actionItems: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.personID = personID
        self.transcript = transcript
        self.summary = summary
        self.suggestedNote = suggestedNote
        self.actionItems = actionItems
        self.createdAt = createdAt
    }
}

// MARK: - Tolerant decoding
//
// These types live in the data file shared by the app and widget. A key that's missing (a file written before
// the field existed) gets the same default as `init`, so one new field never makes an older file unreadable.
// Encoding is still synthesized, so the file format doesn't change. When you add a stored field, decode it here
// with `decodeIfPresent(...) ?? <default>` (even if it's optional) and add a test in `CompatibilityTests`. The
// compiler won't catch a missed field when `init` gives it a default: it would be saved but reset on every load.

extension Person {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(UUID.self, forKey: .id),
            name: c.decode(String.self, forKey: .name),
            relationship: c.decodeIfPresent(String.self, forKey: .relationship) ?? "",
            phone: c.decodeIfPresent(String.self, forKey: .phone) ?? "",
            cadenceDays: c.decodeIfPresent(Int.self, forKey: .cadenceDays) ?? 7,
            lastContacted: c.decodeIfPresent(Date.self, forKey: .lastContacted),
            notes: c.decodeIfPresent(String.self, forKey: .notes) ?? "",
            snoozedUntil: c.decodeIfPresent(Date.self, forKey: .snoozedUntil),
            isFavorite: c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        )
    }
}

extension LifeContext {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            projects: c.decodeIfPresent([String].self, forKey: .projects) ?? [],
            notes: c.decodeIfPresent(String.self, forKey: .notes) ?? "",
            upcomingEvents: c.decodeIfPresent([String].self, forKey: .upcomingEvents) ?? []
        )
    }
}

extension Opener {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            personID: c.decode(UUID.self, forKey: .personID),
            text: c.decode(String.self, forKey: .text),
            isAI: c.decodeIfPresent(Bool.self, forKey: .isAI) ?? false,
            // Not `.now` like `init`: an opener of unknown age is treated as stale, so it gets rewritten.
            createdAt: c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
        )
    }
}

extension CatchUpNote {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(UUID.self, forKey: .id),
            personID: c.decodeIfPresent(UUID.self, forKey: .personID),
            transcript: c.decodeIfPresent(String.self, forKey: .transcript) ?? "",
            summary: c.decodeIfPresent(String.self, forKey: .summary) ?? "",
            suggestedNote: c.decodeIfPresent(String.self, forKey: .suggestedNote) ?? "",
            actionItems: c.decodeIfPresent([String].self, forKey: .actionItems) ?? [],
            // Not `.now` like `init`: a note of unknown age shouldn't jump to the top of the list on every load.
            createdAt: c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
        )
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
