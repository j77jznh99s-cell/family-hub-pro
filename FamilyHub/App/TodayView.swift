import FamilyHubCore
import SwiftUI

/// The main screen: who to text today, each with a ready-to-send opener and one big button.
struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if model.data.people.isEmpty {
                    ContentUnavailableView {
                        Label("Add your people", systemImage: "person.badge.plus")
                    } description: {
                        Text("Pick family and friends in the People tab, and Family Hub will tell you when it's been a while — and what to say.")
                    }
                } else if model.suggestions.isEmpty {
                    ContentUnavailableView(
                        "You're all caught up",
                        systemImage: "checkmark.seal.fill",
                        description: Text("Nobody's due for a text right now. Nice work!")
                    )
                } else {
                    list
                }
            }
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

    private var list: some View {
        List {
            if let error = model.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(model.suggestions) { s in
                SuggestionCard(suggestion: s)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
    }
}

struct SuggestionCard: View {
    @Environment(AppModel.self) private var model
    let suggestion: Suggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(suggestion.person.name)
                    .font(.title3.bold())
                if suggestion.person.isFavorite {
                    Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                }
                Spacer()
                UrgencyBadge(suggestion: suggestion)
            }

            Text(suggestion.opener.text)
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

struct UrgencyBadge: View {
    let suggestion: Suggestion

    var body: some View {
        Text(suggestion.sinceLabel)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch suggestion.urgency {
        case .overdue: return .red
        case .due: return .orange
        case .dueSoon: return .blue
        case .upToDate: return .green
        }
    }
}
