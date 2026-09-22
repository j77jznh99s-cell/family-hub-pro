import EventKit
import FamilyHubCore
import Foundation
import Observation
import UIKit
import UserNotifications
import WidgetKit

/// Single source of truth for the app. Every change is saved to the shared store and the widgets are told to reload.
@MainActor
@Observable
final class AppModel {
    private(set) var data: AppData
    var isRefreshingOpeners = false
    var lastError: String?
    /// Set by a widget tap or the Text button; drives the message composer sheet.
    var composeTarget: ComposeTarget?
    /// Set after a reach-out is logged; drives the celebration overlay.
    var celebration: ReachOutResult?
    /// Bumped whenever a photo changes so views reload their images.
    private(set) var photoVersion = 0
    var selectedTab: Tab = .today

    enum Tab: Hashable { case today, favorites, progress, people, me }

    @ObservationIgnored private let store: Store
    @ObservationIgnored private let eventStore = EKEventStore()

    struct ComposeTarget: Identifiable {
        let person: Person
        let body: String
        var id: UUID { person.id }
    }

    init(store: Store = .shared) {
        self.store = store
        self.data = store.load()
    }

    var suggestions: [Suggestion] { data.suggestions() }

    /// Pick up changes made while we were in the background (e.g. the widget's "I texted them" button).
    func reload() {
        let latest = store.load()
        if latest != data { data = latest }
        scheduleReminder()
    }

    var sortedPeople: [Person] {
        data.people.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Mutations

    func update(_ change: (inout AppData) -> Void) {
        change(&data)
        do {
            try store.save(data)
        } catch {
            lastError = "Couldn't save: \(error.localizedDescription)"
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func upsert(_ person: Person) {
        update { d in
            if let i = d.people.firstIndex(where: { $0.id == person.id }) {
                d.people[i] = person
            } else {
                d.people.append(person)
            }
        }
    }

    func delete(_ ids: [UUID]) {
        update { d in
            d.people.removeAll { ids.contains($0.id) }
            for id in ids { d.openers[id] = nil }
        }
        for id in ids { setPhoto(nil, for: id) }
    }

    /// Log a reach-out and celebrate it (points, streak, badges).
    @discardableResult
    func markContacted(_ id: UUID, celebrate: Bool = true) -> ReachOutResult? {
        var result: ReachOutResult?
        update { result = $0.markContacted(id) }
        if celebrate { self.celebrate(result) }
        scheduleReminder()
        return result
    }

    /// Show the celebration, optionally after a sheet has finished sliding away.
    func celebrate(_ result: ReachOutResult?, after delay: Duration = .zero) {
        guard let result, result.counted else { return }
        Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            celebration = result
        }
    }

    func person(_ id: UUID) -> Person? { data.people.first { $0.id == id } }

    // MARK: - Engagement

    var theme: Theme { data.preferences.theme }
    var streak: StreakStatus { data.streakStatus() }
    var level: Level { data.level }

    func setPreferences(_ change: (inout Preferences) -> Void) {
        update { change(&$0.preferences) }
        scheduleReminder()
    }

    // MARK: - Photos

    var hasBackground: Bool {
        _ = photoVersion
        return store.hasBackground
    }

    var backgroundImage: UIImage? { ImageCache.image(at: store.backgroundURL) }

    func photo(for id: UUID) -> UIImage? { ImageCache.image(at: store.photoURL(for: id)) }

    /// Pass nil to remove. Photos are shrunk before saving so the widget can load them cheaply.
    func setPhoto(_ data: Data?, for id: UUID) {
        writeImage(data.flatMap { ImageCache.jpeg(from: $0, maxSide: 400) }, remove: data == nil, to: store.photoURL(for: id))
    }

    func setBackground(_ data: Data?) {
        writeImage(data.flatMap { ImageCache.jpeg(from: $0, maxSide: 1200) }, remove: data == nil, to: store.backgroundURL)
    }

    private func writeImage(_ jpeg: Data?, remove: Bool, to url: URL) {
        guard jpeg != nil || remove else {
            lastError = "Couldn't read that photo."
            return
        }
        do {
            try store.writeImage(jpeg, to: url)
        } catch {
            lastError = "Couldn't save the photo: \(error.localizedDescription)"
        }
        ImageCache.invalidate(url)
        photoVersion += 1
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Reminders

    /// Turn on the daily nudge; asks for notification permission the first time.
    func enableReminders(_ on: Bool) async {
        if on {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            setPreferences { $0.remindersOn = granted }
            if !granted { lastError = "Notifications are off for Family Hub. Turn them on in the Settings app." }
        } else {
            setPreferences { $0.remindersOn = false }
        }
    }

    /// Keeps exactly one pending reminder: at your chosen time today if that's still ahead and there's a reason
    /// to nudge, otherwise tomorrow. Re-run after every change so the text is always current.
    func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])
        let prefs = data.preferences
        guard prefs.remindersOn else { return }

        let cal = Calendar.current
        let now = Date.now
        guard var fire = cal.date(bySettingHour: prefs.reminderHour, minute: prefs.reminderMinute, second: 0, of: now) else { return }
        var text = Engagement.reminder(for: data, now: now)
        if fire <= now || text == nil {
            fire = cal.date(byAdding: .day, value: 1, to: fire) ?? fire
            text = Engagement.reminder(for: data, now: fire)
                ?? ("💬 Who will you text today?", "Open Family Hub for today's suggestions.")
        }
        guard let text else { return }

        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = .default
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let request = UNNotificationRequest(
            identifier: "daily-reminder",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        )
        center.add(request)
    }

    func snooze(_ id: UUID, days: Int) { update { $0.snooze(id, days: days) } }

    func setContext(_ context: LifeContext) { update { $0.context = context } }

    func appendNote(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update { d in
            d.context.notes = d.context.notes.isEmpty ? trimmed : d.context.notes + "\n" + trimmed
        }
    }

    func compose(_ suggestion: Suggestion) {
        composeTarget = ComposeTarget(person: suggestion.person, body: suggestion.opener.text)
    }

    func compose(personID: UUID) {
        guard let s = data.suggestions(includeUpToDate: true).first(where: { $0.person.id == personID }) else { return }
        compose(s)
    }

    // MARK: - Deep links

    /// familyhub://text/<uuid>        → open the composer for that person (widget taps)
    /// familyhub://note?text=...      → add a line to "My week" (for Shortcuts / share sheet)
    func handle(url: URL) {
        guard url.scheme == "familyhub" else { return }
        switch url.host {
        case "text":
            if let id = UUID(uuidString: url.lastPathComponent) { compose(personID: id) }
        case "note":
            let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "text" })?.value
            if let text { appendNote(text) }
        default:
            break
        }
    }

    // MARK: - AI openers

    /// Refresh openers when they're missing, older than the max age, or your notes changed.
    /// Cheap to call on every foreground: it returns immediately when nothing's stale.
    func refreshOpenersIfNeeded(force: Bool = false) async {
        guard !isRefreshingOpeners else { return }
        let apiKey = Keychain.apiKey ?? ""
        guard !apiKey.isEmpty else { return }

        await refreshCalendarIfAllowed()

        let targets = Array(data.suggestions().prefix(8).map(\.person))
        guard !targets.isEmpty else { return }
        let hash = OpenerGenerator.inputHash(people: targets, context: data.context)
        let allFresh = targets.allSatisfy { p in
            data.openers[p.id].map { $0.isAI && SuggestionEngine.isFresh($0, now: .now) } ?? false
        }
        if !force, allFresh, hash == data.openersInputHash { return }

        isRefreshingOpeners = true
        defer { isRefreshingOpeners = false }
        do {
            let generator = OpenerGenerator(apiKey: apiKey, model: Prefs.model)
            let fresh = try await generator.generate(for: targets, context: data.context)
            update { d in
                d.openers.merge(fresh) { _, new in new }
                d.openersRefreshedAt = .now
                d.openersInputHash = hash
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Calendar

    var calendarEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "calendarEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "calendarEnabled") }
    }

    func requestCalendarAccess() async -> Bool {
        let granted = (try? await eventStore.requestFullAccessToEvents()) ?? false
        calendarEnabled = granted
        if granted { await refreshCalendarIfAllowed() }
        return granted
    }

    func refreshCalendarIfAllowed() async {
        guard calendarEnabled, EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        let start = Date.now
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else { return }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let titles = eventStore.events(matching: predicate)
            .prefix(10)
            .compactMap { e in e.title.map { "\($0) (\(formatter.string(from: e.startDate)))" } }
        if titles != data.context.upcomingEvents {
            update { $0.context.upcomingEvents = titles }
        }
    }
}

/// Small user preferences that don't belong in the shared store.
enum Prefs {
    static var model: String {
        get { UserDefaults.standard.string(forKey: "claudeModel") ?? OpenerGenerator.defaultModel }
        set { UserDefaults.standard.set(newValue, forKey: "claudeModel") }
    }
}
