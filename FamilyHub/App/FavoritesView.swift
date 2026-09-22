import FamilyHubCore
import SwiftUI

/// Your inner circle at a glance: big photos with a ring that fills as each person comes due.
struct FavoritesView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Person?
    @State private var picking = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if model.data.favorites.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(model.data.favorites) { person in
                            FavoriteTile(person: person)
                                .contextMenu {
                                    Button("I texted \(person.firstName)", systemImage: "checkmark") { model.markContacted(person.id) }
                                    Button("Edit", systemImage: "pencil") { editing = person }
                                    Button("Remove from favorites", systemImage: "star.slash") {
                                        var p = person
                                        p.isFavorite = false
                                        model.upsert(p)
                                    }
                                }
                        }
                    }
                    .padding(16)
                    Text("Tap to text. Press and hold for more.")
                        .font(.footnote)
                        .foregroundStyle(model.hasBackground ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                        .padding(.bottom, 20)
                }
            }
            .background(AppBackground())
            .navigationTitle("Favorites")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Choose", systemImage: "star") { picking = true }
                }
            }
            .sheet(item: $editing) { person in
                PersonEditor(person: person) { model.upsert($0) }
            }
            .sheet(isPresented: $picking) { FavoritePicker() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(model.theme.gradient)
            Text("Your favorite people").font(.title2.bold())
            Text("Star the people who matter most and they'll live here, with their photos, so you never lose touch.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Choose favorites") { picking = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .card()
        .padding(16)
        .padding(.top, 40)
    }
}

struct FavoriteTile: View {
    @Environment(AppModel.self) private var model
    let person: Person

    var body: some View {
        let suggestion = model.data.suggestions(includeUpToDate: true).first { $0.person.id == person.id }
        let days = suggestion?.daysSince
        let fill = days.map { min(1, Double($0) / Double(max(1, person.cadenceDays))) } ?? 1
        let urgency = suggestion?.urgency ?? .overdue
        let personStreak = model.data.personStreak(person)

        Button {
            model.compose(personID: person.id)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: fill)
                        .stroke(urgency.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Avatar(person: person, size: 92)
                }
                .frame(width: 108, height: 108)
                .overlay(alignment: .bottomTrailing) {
                    if personStreak > 1 {
                        Label("\(personStreak)", systemImage: "flame.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(.orange, in: Capsule())
                            .foregroundStyle(.white)
                            .accessibilityLabel("\(personStreak) check-ins in a row")
                    }
                }

                Text(person.firstName).font(.headline).lineLimit(1)
                Text(caption(suggestion))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(urgency.color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .card()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Text \(person.name)")
    }

    private func caption(_ s: Suggestion?) -> String {
        guard let s else { return "Snoozed" }
        guard let days = s.daysSince else { return "Not texted yet" }
        guard s.urgency == .upToDate else { return s.sinceLabel }
        switch days {
        case 0: return "Talked today"
        case 1: return "Talked yesterday"
        default: return "Talked \(days) days ago"
        }
    }
}

/// Quick star/unstar list.
struct FavoritePicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(model.sortedPeople) { person in
                Button {
                    var p = person
                    p.isFavorite.toggle()
                    model.upsert(p)
                } label: {
                    HStack(spacing: 12) {
                        Avatar(person: person, size: 40)
                        Text(person.name).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: person.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(person.isFavorite ? Color.yellow : Color.secondary)
                            .font(.title3)
                    }
                }
            }
            .overlay {
                if model.data.people.isEmpty {
                    ContentUnavailableView("Add people first", systemImage: "person.badge.plus", description: Text("Add people in the People tab, then star your favorites here."))
                }
            }
            .navigationTitle("Choose favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
