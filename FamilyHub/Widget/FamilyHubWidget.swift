import AppIntents
import FamilyHubCore
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Timeline

struct SuggestionEntry: TimelineEntry {
    let date: Date
    let suggestions: [Suggestion]
    let hasPeople: Bool
    var streak: StreakStatus = .none
    var theme: Theme = .coral
    /// Photos for the people on screen, decoded once per timeline (widgets have a tight memory budget).
    var photos: [UUID: UIImage] = [:]
    var background: UIImage?

    static let placeholder = SuggestionEntry(
        date: .now,
        suggestions: [
            Suggestion(
                person: Person(name: "Mom", relationship: "mom"),
                daysSince: 9, urgency: .overdue, score: 3,
                opener: Opener(personID: UUID(), text: "Hi Mom! How's the garden coming along?", isAI: true)
            ),
            Suggestion(
                person: Person(name: "Jake"),
                daysSince: 7, urgency: .due, score: 1,
                opener: Opener(personID: UUID(), text: "Yo! Did you end up going to the game?", isAI: true)
            ),
        ],
        hasPeople: true
    )
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SuggestionEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (SuggestionEntry) -> Void) {
        let entry = Self.entry(at: .now)
        completion(context.isPreview && !entry.hasPeople ? .placeholder : entry)
    }

    /// Reads the shared file once and precomputes entries for now and the next few midnights,
    /// so "days since" ticks over on its own without the app running. No network, ever.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SuggestionEntry>) -> Void) {
        let data = Store.shared.load()
        let cal = Calendar.current
        var dates = [Date.now]
        var next = cal.startOfDay(for: .now)
        for _ in 0..<3 {
            next = cal.date(byAdding: .day, value: 1, to: next)!
            dates.append(next.addingTimeInterval(60))
        }
        let photos = Self.photos(for: data.suggestions(now: .now))
        let background = UIImage(contentsOfFile: Store.shared.backgroundURL.path)
        let entries = dates.map { date in
            Self.entry(data: data, at: date, photos: photos, background: background)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static func entry(at date: Date) -> SuggestionEntry {
        let data = Store.shared.load()
        let photos = photos(for: data.suggestions(now: date))
        return entry(data: data, at: date, photos: photos, background: UIImage(contentsOfFile: Store.shared.backgroundURL.path))
    }

    static func entry(data: AppData, at date: Date, photos: [UUID: UIImage], background: UIImage?) -> SuggestionEntry {
        SuggestionEntry(
            date: date,
            suggestions: data.suggestions(now: date),
            hasPeople: !data.people.isEmpty,
            streak: data.streakStatus(now: date),
            theme: data.preferences.theme,
            photos: photos,
            background: background
        )
    }

    static func photos(for suggestions: [Suggestion]) -> [UUID: UIImage] {
        var result: [UUID: UIImage] = [:]
        for s in suggestions.prefix(3) {
            if let image = UIImage(contentsOfFile: Store.shared.photoURL(for: s.person.id).path) { result[s.person.id] = image }
        }
        return result
    }
}

// MARK: - Interactive "I texted them" button (home screen, iOS 17+)

struct MarkTextedIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark as Texted"
    static var isDiscoverable = false

    @Parameter(title: "Person ID") var personID: String

    init() {}
    init(personID: UUID) { self.personID = personID.uuidString }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: personID) else { return .result() }
        var data = Store.shared.load()
        data.markContacted(id)
        try Store.shared.save(data)
        return .result()
    }
}

// MARK: - Views

func textURL(_ s: Suggestion) -> URL {
    URL(string: "familyhub://text/\(s.person.id.uuidString)")!
}

private func color(_ hex: UInt32) -> Color {
    Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
}

private func urgencyColor(_ u: Urgency) -> Color {
    switch u {
    case .overdue: return .red
    case .due: return .orange
    case .dueSoon: return .blue
    case .upToDate: return .green
    }
}

struct FamilyHubWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SuggestionEntry

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    private var top: Suggestion? { entry.suggestions.first }
    private var accent: Color { color(entry.theme.colors.0) }
    private var emptyText: String { entry.hasPeople ? "All caught up" : "Add people" }

    // Lock screen, above the clock: "💬 Text Mom · 9 days"
    @ViewBuilder private var inline: some View {
        if let top {
            Label("Text \(top.person.firstName) · \(top.sinceLabel)", systemImage: "message.fill")
                .widgetURL(textURL(top))
        } else if entry.streak.current > 0 {
            Label("\(entry.streak.current)-day streak", systemImage: "flame.fill")
        } else {
            Label(emptyText, systemImage: "checkmark.message")
        }
    }

    // Lock screen circle: your streak, or how many people are waiting if you don't have one yet.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: entry.streak.current > 0 ? "flame.fill" : "message.fill").font(.caption)
                Text("\(entry.streak.current > 0 ? entry.streak.current : entry.suggestions.count)")
                    .font(.title3.bold())
                    .minimumScaleFactor(0.6)
            }
        }
        .widgetURL(top.map(textURL))
        .accessibilityLabel(entry.streak.current > 0 ? "\(entry.streak.current) day streak" : "\(entry.suggestions.count) people to text")
    }

    // Lock screen rectangle: who + what to say.
    @ViewBuilder private var rectangular: some View {
        if let top {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "message.fill")
                    Text("Text \(top.person.firstName)").fontWeight(.semibold)
                    Text("· \(top.sinceLabel)").foregroundStyle(.secondary)
                }
                .font(.headline)
                .widgetAccentable()
                Text(top.opener.text)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(textURL(top))
        } else {
            Label(entry.streak.current > 0 ? "🔥 \(entry.streak.current)-day streak · all caught up" : emptyText, systemImage: "checkmark.message")
        }
    }

    private func avatar(_ person: Person, size: CGFloat) -> some View {
        Group {
            if let image = entry.photos[person.id] {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [accent, color(entry.theme.colors.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(String(person.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var streakChip: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
            Text("\(entry.streak.current)")
        }
        .font(.caption.bold())
        .foregroundStyle(entry.streak.current > 0 ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
        .accessibilityLabel("\(entry.streak.current) day streak")
    }

    private func checkButton(_ s: Suggestion) -> some View {
        Button(intent: MarkTextedIntent(personID: s.person.id)) {
            Image(systemName: "checkmark.circle.fill").font(.title3)
        }
        .buttonStyle(.plain)
        .foregroundStyle(accent)
        .accessibilityLabel("I texted \(s.person.firstName)")
    }

    @ViewBuilder private var small: some View {
        if let top {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    avatar(top.person, size: 38)
                    Spacer(minLength: 0)
                    checkButton(top)
                }
                HStack(spacing: 4) {
                    Text(top.person.firstName).font(.headline).lineLimit(1)
                    Spacer(minLength: 0)
                    streakChip
                }
                Text(top.sinceLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(urgencyColor(top.urgency))
                Text(top.opener.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetURL(textURL(top))
        } else {
            empty
        }
    }

    @ViewBuilder private var medium: some View {
        if entry.suggestions.isEmpty {
            empty
        } else {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Who to text").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Spacer()
                    streakChip
                }
                ForEach(entry.suggestions.prefix(3)) { s in
                    HStack(spacing: 8) {
                        Link(destination: textURL(s)) {
                            HStack(spacing: 8) {
                                avatar(s.person, size: 30)
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 4) {
                                        Text(s.person.firstName).font(.subheadline.bold())
                                        Text(s.sinceLabel)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(urgencyColor(s.urgency))
                                    }
                                    Text(s.opener.text)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        checkButton(s)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: entry.hasPeople ? "checkmark.seal.fill" : "person.badge.plus")
                .font(.title2)
                .foregroundStyle(accent)
            Text(emptyText).font(.caption.weight(.semibold))
            if entry.streak.current > 0 { streakChip }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// On a photo background, home screen widgets switch to light-on-dark text; otherwise they follow the system.
struct WidgetRoot: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetFamily) private var family
    let entry: SuggestionEntry

    var body: some View {
        let onPhoto = entry.background != nil && (family == .systemSmall || family == .systemMedium)
        FamilyHubWidgetView(entry: entry)
            .environment(\.colorScheme, onPhoto ? .dark : scheme)
    }
}

/// Your background photo behind the home screen widgets (dimmed, with light text), or the system fill.
struct WidgetBackground: View {
    let entry: SuggestionEntry

    var body: some View {
        if let image = entry.background {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.45))
        } else {
            Color(.secondarySystemBackground)
        }
    }
}

// MARK: - Widget

struct FamilyHubWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FamilyHubWidget", provider: Provider()) { entry in
            WidgetRoot(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground(entry: entry) }
        }
        .configurationDisplayName("Who to Text")
        .description("Who's due for a text, what to say, and your streak. Tap to open it in Messages.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

@main
struct FamilyHubWidgetBundle: WidgetBundle {
    var body: some Widget {
        FamilyHubWidget()
    }
}
