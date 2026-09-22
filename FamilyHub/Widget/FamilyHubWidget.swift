import AppIntents
import FamilyHubCore
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct SuggestionEntry: TimelineEntry {
    let date: Date
    let suggestions: [Suggestion]
    let hasPeople: Bool

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
        let entries = dates.map { date in
            SuggestionEntry(date: date, suggestions: data.suggestions(now: date), hasPeople: !data.people.isEmpty)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static func entry(at date: Date) -> SuggestionEntry {
        let data = Store.shared.load()
        return SuggestionEntry(date: date, suggestions: data.suggestions(now: date), hasPeople: !data.people.isEmpty)
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

    private var emptyText: String { entry.hasPeople ? "All caught up" : "Add people" }

    // Lock screen, above the clock: "💬 Text Mom · 9 days"
    @ViewBuilder private var inline: some View {
        if let top {
            Label("Text \(top.person.firstName) · \(top.sinceLabel)", systemImage: "message.fill")
                .widgetURL(textURL(top))
        } else {
            Label(emptyText, systemImage: "checkmark.message")
        }
    }

    // Lock screen, small circle: how many people are waiting on a text.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "message.fill").font(.caption)
                Text("\(entry.suggestions.count)").font(.title3.bold())
            }
        }
        .widgetURL(top.map(textURL))
        .accessibilityLabel("\(entry.suggestions.count) people to text")
    }

    // Lock screen, rectangle: who + what to say.
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
            Label(emptyText, systemImage: "checkmark.message")
        }
    }

    @ViewBuilder private var small: some View {
        if let top {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(top.person.firstName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button(intent: MarkTextedIntent(personID: top.person.id)) {
                        Image(systemName: "checkmark.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("I texted \(top.person.firstName)")
                }
                Text(top.sinceLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color(top.urgency))
                Text(top.opener.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
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
            VStack(alignment: .leading, spacing: 8) {
                ForEach(entry.suggestions.prefix(3)) { s in
                    HStack(alignment: .top, spacing: 8) {
                        Link(destination: textURL(s)) {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(s.person.firstName).font(.subheadline.bold())
                                    Text(s.sinceLabel)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(color(s.urgency))
                                }
                                Text(s.opener.text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button(intent: MarkTextedIntent(personID: s.person.id)) {
                            Image(systemName: "checkmark.circle").font(.title3)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("I texted \(s.person.firstName)")
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
                .foregroundStyle(.tint)
            Text(emptyText).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func color(_ u: Urgency) -> Color {
        switch u {
        case .overdue: return .red
        case .due: return .orange
        case .dueSoon: return .blue
        case .upToDate: return .green
        }
    }
}

// MARK: - Widget

struct FamilyHubWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FamilyHubWidget", provider: Provider()) { entry in
            FamilyHubWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Who to Text")
        .description("Who's due for a text, and a message to start with. Tap to open it in Messages.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

@main
struct FamilyHubWidgetBundle: WidgetBundle {
    var body: some Widget {
        FamilyHubWidget()
    }
}
