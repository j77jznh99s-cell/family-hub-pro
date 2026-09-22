import ContactsUI
import FamilyHubCore
import PhotosUI
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
                    for c in picked where c.person.phone.isEmpty || !known.contains(c.person.phone) {
                        model.upsert(c.person)
                        if let photo = c.photo { model.setPhoto(photo, for: c.person.id) }
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
        HStack(spacing: 12) {
            Avatar(person: person, size: 44)
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
    @Environment(AppModel.self) private var model
    @State var person: Person
    let onSave: (Person) -> Void
    @State private var pickerItem: PhotosPickerItem?
    /// nil = unchanged, .some(nil) = remove, .some(data) = new photo.
    @State private var photoChange: Data??

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

    private var hasPhoto: Bool {
        switch photoChange {
        case .some(.some): return true
        case .some(.none): return false
        case .none: return model.photo(for: person.id) != nil
        }
    }

    @ViewBuilder private var photoPreview: some View {
        if case .some(.some(let data)) = photoChange, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if case .some(.none) = photoChange {
            Avatar(person: Person(id: UUID(), name: person.name), size: 96)
        } else {
            Avatar(person: person, size: 96)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            photoPreview
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                            HStack(spacing: 16) {
                                PhotosPicker(selection: $pickerItem, matching: .images) {
                                    Text(hasPhoto ? "Change photo" : "Add photo")
                                }
                                if hasPhoto {
                                    Button("Remove", role: .destructive) { photoChange = .some(nil) }
                                }
                            }
                            .font(.subheadline)
                            .buttonStyle(.borderless)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
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
                    TextField("What's going on with them? (the new job, the Denver trip…)", text: $person.notes, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Short topics work best, like “the new job” or “the Denver trip”. Used to write conversation starters.")
                }
            }
            .navigationTitle(person.name.isEmpty ? "New person" : person.name)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) { photoChange = .some(data) }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        person.name = person.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(person)
                        if let change = photoChange { model.setPhoto(change, for: person.id) }
                        dismiss()
                    }
                    .disabled(person.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct PickedContact {
    let person: Person
    let photo: Data?
}

/// System contact picker. Runs out-of-process, so it needs no Contacts permission and sees only what you pick.
struct ContactPicker: UIViewControllerRepresentable {
    let onPick: ([PickedContact]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let vc = CNContactPickerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: ([PickedContact]) -> Void
        init(onPick: @escaping ([PickedContact]) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onPick(contacts.compactMap { c in
                let name = CNContactFormatter.string(from: c, style: .fullName)
                    ?? [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                guard !name.isEmpty else { return nil }
                let phone = c.phoneNumbers.first(where: { $0.label == CNLabelPhoneNumberMobile || $0.label == CNLabelPhoneNumberiPhone })
                    ?? c.phoneNumbers.first
                let photo = c.isKeyAvailable(CNContactThumbnailImageDataKey) ? c.thumbnailImageData : nil
                return PickedContact(person: Person(name: name, phone: phone?.value.stringValue ?? ""), photo: photo)
            })
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onPick([])
        }
    }
}
