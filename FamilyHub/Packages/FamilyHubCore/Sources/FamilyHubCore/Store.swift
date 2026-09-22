import Foundation

/// Everything the app knows, in one small JSON file shared with the widget through an App Group.
/// A few hundred contacts is well under 100 KB, so a single atomic file read/write is fastest and simplest.
public struct AppData: Codable, Equatable, Sendable {
    public var people: [Person]
    public var openers: [UUID: Opener]
    public var context: LifeContext
    /// When the AI openers were last refreshed (nil = never).
    public var openersRefreshedAt: Date?
    /// Hash of the inputs the current AI openers were written from; a change means they're stale.
    public var openersInputHash: String?
    /// Every reach-out, oldest first. Streaks, points and badges are all computed from this.
    public var log: [ReachOut]
    /// Badge raw value → when it was earned.
    public var badges: [String: Date]
    public var preferences: Preferences

    public init(
        people: [Person] = [],
        openers: [UUID: Opener] = [:],
        context: LifeContext = LifeContext(),
        openersRefreshedAt: Date? = nil,
        openersInputHash: String? = nil,
        log: [ReachOut] = [],
        badges: [String: Date] = [:],
        preferences: Preferences = Preferences()
    ) {
        self.people = people
        self.openers = openers
        self.context = context
        self.openersRefreshedAt = openersRefreshedAt
        self.openersInputHash = openersInputHash
        self.log = log
        self.badges = badges
        self.preferences = preferences
    }

    enum CodingKeys: String, CodingKey {
        case people, openers, context, openersRefreshedAt, openersInputHash, log, badges, preferences
    }

    /// Tolerant of files written by older versions: anything missing gets its default instead of failing the whole load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        people = try c.decodeIfPresent([Person].self, forKey: .people) ?? []
        openers = try c.decodeIfPresent([UUID: Opener].self, forKey: .openers) ?? [:]
        context = try c.decodeIfPresent(LifeContext.self, forKey: .context) ?? LifeContext()
        openersRefreshedAt = try c.decodeIfPresent(Date.self, forKey: .openersRefreshedAt)
        openersInputHash = try c.decodeIfPresent(String.self, forKey: .openersInputHash)
        log = try c.decodeIfPresent([ReachOut].self, forKey: .log) ?? []
        badges = try c.decodeIfPresent([String: Date].self, forKey: .badges) ?? [:]
        preferences = try c.decodeIfPresent(Preferences.self, forKey: .preferences) ?? Preferences()
    }

    public func suggestions(now: Date = .now, includeUpToDate: Bool = false) -> [Suggestion] {
        SuggestionEngine.suggestions(
            people: people, openers: openers, context: context,
            now: now, includeUpToDate: includeUpToDate
        )
    }

    public var favorites: [Person] {
        people.filter(\.isFavorite).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public mutating func snooze(_ id: UUID, days: Int, from date: Date = .now, calendar: Calendar = .current) {
        guard let i = people.firstIndex(where: { $0.id == id }) else { return }
        people[i].snoozedUntil = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date))
    }
}

public final class Store: @unchecked Sendable {
    /// Set per-build from `APP_GROUP_ID` in project.yml (via the `FHAppGroupID` Info.plist key) so the app and
    /// widget always agree; the literal is only a fallback for tests and previews.
    public static let appGroupID = Bundle.main.object(forInfoDictionaryKey: "FHAppGroupID") as? String
        ?? "group.com.familyhub.shared"
    static let fileName = "familyhub.json"

    public let url: URL
    private let lock = NSLock()

    /// Shared container when the App Group entitlement is present; falls back to Application Support
    /// so previews, tests and a misconfigured build still work.
    public static let shared = Store(url: defaultURL())

    public init(url: URL) {
        self.url = url
    }

    public static func defaultURL() -> URL {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return group.appendingPathComponent(fileName)
        }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    // MARK: Photos (JPEG files next to the JSON so the widget can read them too)

    public var photosDirectory: URL { url.deletingLastPathComponent().appendingPathComponent("Photos", isDirectory: true) }

    public func photoURL(for id: UUID) -> URL { photosDirectory.appendingPathComponent("\(id.uuidString).jpg") }

    public var backgroundURL: URL { photosDirectory.appendingPathComponent("background.jpg") }

    public func hasPhoto(for id: UUID) -> Bool { FileManager.default.fileExists(atPath: photoURL(for: id).path) }

    public var hasBackground: Bool { FileManager.default.fileExists(atPath: backgroundURL.path) }

    /// Writes (or with nil, removes) an image file. Callers pass already-downscaled JPEG data.
    public func writeImage(_ data: Data?, to fileURL: URL) throws {
        try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        if let data {
            try data.write(to: fileURL, options: [.atomic])
        } else if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    public func load() -> AppData {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url) else { return AppData() }
        return (try? Self.decoder.decode(AppData.self, from: data)) ?? AppData()
    }

    public func save(_ appData: AppData) throws {
        lock.lock(); defer { lock.unlock() }
        let data = try Self.encoder.encode(appData)
        try data.write(to: url, options: [.atomic])
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
