import FamilyHubCore
import SwiftUI

/// The main screen: your streak up top, then who to text today, each with a ready-to-send opener.
struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    StreakHeader()
                    if let error = model.lastError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .card()
                    }
                    content
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refreshOpenersIfNeeded(force: true) }
                    } label: {
                        if model.isRefreshingOpeners {
                            ProgressView()
                        } else {
                            Label("New ideas", systemImage: "sparkles")
                        }
                    }
                    .disabled(model.isRefreshingOpeners || Keychain.apiKey == nil)
                }
            }
            .refreshable { await model.refreshOpenersIfNeeded(force: true) }
        }
    }

    @ViewBuilder private var content: some View {
        if model.data.people.isEmpty {
            EmptyCard(symbol: "person.badge.plus", title: "Add your people",
                      message: "Pick family and friends in the People tab, and Family Hub will tell you when it's been a while — and what to say.")
        } else if model.suggestions.isEmpty {
            EmptyCard(symbol: "checkmark.seal.fill", title: "You're all caught up",
                      message: "Nobody's due for a text right now. Nice work!")
        } else {
            ForEach(model.suggestions) { SuggestionCard(suggestion: $0) }
        }
    }
}

/// Streak flame, today's goal and level, all in one tappable strip that opens Progress.
struct StreakHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let s = model.streak
        let level = model.level
        Button {
            model.selectedTab = .progress
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(1, Double(s.doneToday) / Double(max(1, s.goal))))
                        .stroke(s.goalMetToday ? Color.green : model.theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(s.current > 0 ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.secondary))
                        .symbolEffect(.bounce, value: s.current)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 2) {
                    Text(s.current == 1 ? "1 day streak" : "\(s.current) day streak")
                        .font(.headline)
                    Text(s.goalMetToday ? "Today's goal done 🎉" : s.atRisk ? "Text someone to keep it going" : "Text someone to start a streak")
                        .font(.subheadline)
                        .foregroundStyle(s.atRisk ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Lv \(level.number)").font(.headline).foregroundStyle(model.theme.accent)
                    ProgressView(value: level.progress)
                        .tint(model.theme.accent)
                        .frame(width: 56)
                    if s.freezes > 0 {
                        Label("\(s.freezes)", systemImage: "snowflake").font(.caption2.bold()).foregroundStyle(.cyan)
                    }
                }
            }
            .padding(14)
            .card()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(s.current) day streak, level \(level.number). Open progress.")
    }
}

struct EmptyCard: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 44)).foregroundStyle(.tint)
            Text(title).font(.title3.bold())
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .card()
        .padding(.top, 20)
    }
}

struct SuggestionCard: View {
    @Environment(AppModel.self) private var model
    let suggestion: Suggestion

    var body: some View {
        let personStreak = model.data.personStreak(suggestion.person)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Avatar(person: suggestion.person, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(suggestion.person.name).font(.headline)
                        if suggestion.person.isFavorite {
                            Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                        }
                    }
                    if personStreak > 1 {
                        Label("\(personStreak) in a row", systemImage: "flame.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                UrgencyBadge(suggestion: suggestion)
            }

            Text(suggestion.opener.text)
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(model.theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .bottomTrailing) {
                    if suggestion.opener.isAI {
                        Image(systemName: "sparkles").font(.caption2).foregroundStyle(.tint).padding(6)
                    }
                }

            HStack(spacing: 10) {
                Button {
                    model.compose(suggestion)
                } label: {
                    Label("Text \(suggestion.person.firstName)", systemImage: "message.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Menu {
                    Button("I already reached out", systemImage: "checkmark") {
                        model.markContacted(suggestion.person.id)
                    }
                    Button("Copy message", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = suggestion.opener.text
                    }
                    Section("Remind me later") {
                        Button("Tomorrow") { model.snooze(suggestion.person.id, days: 1) }
                        Button("In 3 days") { model.snooze(suggestion.person.id, days: 3) }
                        Button("Next week") { model.snooze(suggestion.person.id, days: 7) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("More options")
            }
        }
        .padding()
        .card()
    }
}

struct UrgencyBadge: View {
    let suggestion: Suggestion

    var body: some View {
        Text(suggestion.sinceLabel)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(suggestion.urgency.color.opacity(0.18), in: Capsule())
            .foregroundStyle(suggestion.urgency.color)
    }
}
