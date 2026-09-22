import ContactsUI
import FamilyHubCore
import SwiftUI

struct PeopleView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Person?
    @State private var showingPicker = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.sortedPeople) { person in
                    Button { editing = person } label: { PersonRow(person: person) }
                        .foregroundStyle(.primary)
                        .swipeActions(edge: .leading) {
                            Button("Texted", systemImage: "checkmark") { model.markContacted(person.id) }
                                .tint(.green)
                        }
                }
                .onDelete { offsets in
                    let people = model.sortedPeople
                    model.delete(offsets.map { people[$0].id })
                }
            }
            .overlay {
                if model.data.people.isEmpty {
                    ContentUnavailableView {
                        Label("No one yet", systemImage: "person.2")
                    } description: {
                        Text("Add the people you want to keep in touch with.")
                    } actions: {
                        Button("Choose from Contacts") { showingPicker = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("People")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("From Contacts", systemImage: "person.crop.circle.badge.plus") { showingPicker = true }
                        Button("Type it in", systemImage: "keyboard") { editing = Person(name: "") }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                ContactPicker { picked in
                    showingPicker = false
                    let known = Set(model.data.people.map(\.phone))
                    for p in picked where p.phone.isEmpty || !known.contains(p.phone) {
                        model.upsert(p)
                    }
                    Task { await model.refreshOpenersIfNeeded() }
                }
                .ignoresSafeArea()
            }
            .sheet(item: $editing) { person in
                PersonEditor(person: person) { saved in
                    model.upsert(saved)
                    Task { await model.refreshOpenersIfNeeded() }
                }
            }
        }
    }
}

struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(person.name).font(.headline)
                    if person.isFavorite { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow) }
                }
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        if !person.relationship.isEmpty { parts.append(person.relationship) }
        parts.append(PersonEditor.cadenceLabel(person.cadenceDays))
        if let last = person.lastContacted {
            parts.append("last: " + last.formatted(.relative(presentation: .named)))
        }
        return parts.joined(separator: " · ")
    }
}

struct PersonEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var person: Person
    let onSave: (Person) -> Void

    static let cadences = [1, 2, 3, 5, 7, 10, 14, 21, 30, 60, 90]

    static func cadenceLabel(_ days: Int) -> String {
        switch days {
        case 1: return "every day"
        case 7: return "every week"
        case 14: return "every 2 weeks"
        case 30: return "every month"
        default: return "every \(days) days"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $person.name)
                        .textContentType(.name)
                    TextField("Relationship (Mom, brother, best friend…)", text: $person.relationship)
                    TextField("Phone number", text: $person.phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    Toggle("Favorite", isOn: $person.isFavorite)
                }
                Section {
                    Picker("Text them", selection: $person.cadenceDays) {
                        ForEach(Self.cadences, id: \.self) { Text(Self.cadenceLabel($0)).tag($0) }
                    }
                    DatePicker(
                        "Last texted",
                        selection: Binding(
                            get: { person.lastContacted ?? .now },
                            set: { person.lastContacted = $0 }
                        ),
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                } footer: {
                    Text("Family Hub nudges you once it's been longer than this.")
                }
                Section {
                    TextField("What's going on with them? (new job, trip, kid's recital…)", text: $person.notes, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Used to write better conversation starters. The first line is used even without AI.")
                }
            }
            .navigationTitle(person.name.isEmpty ? "New person" : person.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        person.name = person.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(person)
                        dismiss()
                    }
                    .disabled(person.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// System contact picker. Runs out-of-process, so it needs no Contacts permission and sees only what you pick.
struct ContactPicker: UIViewControllerRepresentable {
    let onPick: ([Person]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let vc = CNContactPickerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: ([Person]) -> Void
        init(onPick: @escaping ([Person]) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onPick(contacts.compactMap { c in
                let name = CNContactFormatter.string(from: c, style: .fullName)
                    ?? [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                guard !name.isEmpty else { return nil }
                let phone = c.phoneNumbers.first(where: { $0.label == CNLabelPhoneNumberMobile || $0.label == CNLabelPhoneNumberiPhone })
                    ?? c.phoneNumbers.first
                return Person(name: name, phone: phone?.value.stringValue ?? "")
            })
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onPick([])
        }
    }
}
