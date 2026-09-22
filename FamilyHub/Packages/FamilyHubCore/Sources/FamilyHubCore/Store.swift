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

    public init(
        people: [Person] = [],
        openers: [UUID: Opener] = [:],
        context: LifeContext = LifeContext(),
        openersRefreshedAt: Date? = nil,
        openersInputHash: String? = nil
    ) {
        self.people = people
        self.openers = openers
        self.context = context
        self.openersRefreshedAt = openersRefreshedAt
        self.openersInputHash = openersInputHash
    }

    public func suggestions(now: Date = .now, includeUpToDate: Bool = false) -> [Suggestion] {
        SuggestionEngine.suggestions(
            people: people, openers: openers, context: context,
            now: now, includeUpToDate: includeUpToDate
        )
    }

    /// Log that you reached out. Clears any snooze and the used opener so tomorrow's is fresh.
    public mutating func markContacted(_ id: UUID, at date: Date = .now) {
        guard let i = people.firstIndex(where: { $0.id == id }) else { return }
        people[i].lastContacted = date
        people[i].snoozedUntil = nil
        openers[id] = nil
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
