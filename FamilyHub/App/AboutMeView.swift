import FamilyHubCore
import PhotosUI
import SwiftUI

/// What you're up to (so openers can mention real things) plus settings.
struct AboutMeView: View {
    @Environment(AppModel.self) private var model
    @State private var context = LifeContext()
    @State private var newProject = ""
    @State private var calendarOn = false
    @State private var apiKey = ""
    @State private var claudeModel = Prefs.model
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                PersonalizeSections()
                Section {
                    ForEach(context.projects, id: \.self) { Text($0) }
                        .onDelete { context.projects.remove(atOffsets: $0); save() }
                    HStack {
                        TextField("Add a project (e.g. building my app)", text: $newProject)
                            .onSubmit(addProject)
                        Button("Add", action: addProject)
                            .disabled(newProject.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("What I'm working on")
                } footer: {
                    Text("Things you're building, learning or working toward. Great conversation material.")
                }

                Section {
                    TextField("Busy week, got a new puppy, dentist Thursday…", text: $context.notes, axis: .vertical)
                        .lineLimit(3...10)
                        // Save a moment after typing stops instead of on every keystroke.
                        .task(id: context.notes) {
                            guard loaded else { return }
                            try? await Task.sleep(for: .seconds(1))
                            if !Task.isCancelled { save() }
                        }
                } header: {
                    Text("My week")
                } footer: {
                    Text("Tip: Shortcuts can add a line here by opening familyhub://note?text=…")
                }

                Section {
                    Toggle("Use my calendar", isOn: $calendarOn)
                        .onChange(of: calendarOn) { _, on in
                            if on {
                                Task {
                                    calendarOn = await model.requestCalendarAccess()
                                    context.upcomingEvents = model.data.context.upcomingEvents
                                }
                            } else {
                                model.calendarEnabled = false
                                context.upcomingEvents = []
                                save()
                            }
                        }
                    if !context.upcomingEvents.isEmpty {
                        ForEach(context.upcomingEvents, id: \.self) {
                            Text($0).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Reads event titles for the next 7 days. Nothing on your calendar is changed.")
                }

                Section {
                    SecureField("Claude API key (sk-ant-…)", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Keychain.apiKey = apiKey }
                    TextField("Model", text: $claudeModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Prefs.model = claudeModel.isEmpty ? OpenerGenerator.defaultModel : claudeModel }
                    Button("Save & write new openers") {
                        Keychain.apiKey = apiKey
                        Prefs.model = claudeModel.isEmpty ? OpenerGenerator.defaultModel : claudeModel
                        Task { await model.refreshOpenersIfNeeded(force: true) }
                    }
                } header: {
                    Text("AI conversation starters")
                } footer: {
                    Text("Optional. Without a key you still get reminders and simple built-in openers. With one, Claude writes openers using first names, relationships, notes and your context above — never phone numbers. Get a key at console.anthropic.com. It's stored in your iPhone's Keychain.")
                }
            }
            .navigationTitle("Me")
            .onAppear {
                // Reload each time the tab opens: a Shortcut or the calendar may have changed things.
                context = model.data.context
                calendarOn = model.calendarEnabled
                apiKey = Keychain.apiKey ?? ""
                loaded = true
            }
            .onDisappear {
                save()
                if apiKey != (Keychain.apiKey ?? "") { Keychain.apiKey = apiKey }
            }
        }
    }

    private func addProject() {
        let p = newProject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty, !context.projects.contains(p) else { return }
        context.projects.append(p)
        newProject = ""
        save()
    }

    private func save() {
        guard loaded else { return }
        // Keep whatever the calendar refresh wrote; this screen only owns projects and notes.
        var merged = model.data.context
        merged.projects = context.projects
        merged.notes = context.notes
        if !calendarOn { merged.upcomingEvents = [] }
        if merged != model.data.context { model.setContext(merged) }
    }
}

/// Theme, background photo, daily goal and reminders.
struct PersonalizeSections: View {
    @Environment(AppModel.self) private var model
    @State private var backgroundItem: PhotosPickerItem?

    var body: some View {
        let prefs = model.data.preferences
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Button {
                            model.setPreferences { $0.theme = theme }
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(theme.gradient)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if theme == prefs.theme {
                                            Image(systemName: "checkmark").font(.headline.bold()).foregroundStyle(.white)
                                        }
                                    }
                                    .overlay(Circle().stroke(theme == prefs.theme ? Color.primary : .clear, lineWidth: 2).padding(-4))
                                Text(theme.displayName).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(theme.displayName) theme\(theme == prefs.theme ? ", selected" : "")")
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }
            PhotosPicker(selection: $backgroundItem, matching: .images) {
                Label(model.hasBackground ? "Change background photo" : "Add a background photo", systemImage: "photo.on.rectangle")
            }
            if model.hasBackground {
                Button("Remove background photo", systemImage: "trash", role: .destructive) { model.setBackground(nil) }
            }
        } header: {
            Text("Make it yours")
        } footer: {
            Text("A favorite family photo makes the app (and your home screen widget) feel like home.")
        }
        .onChange(of: backgroundItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { model.setBackground(data) }
                backgroundItem = nil
            }
        }

        Section {
            Stepper(value: Binding(get: { prefs.dailyGoal }, set: { v in model.setPreferences { $0.dailyGoal = v } }), in: 1...5) {
                Label("Daily goal: \(prefs.dailyGoal) \(prefs.dailyGoal == 1 ? "person" : "people")", systemImage: "target")
            }
            Toggle(isOn: Binding(get: { prefs.remindersOn }, set: { on in Task { await model.enableReminders(on) } })) {
                Label("Daily reminder", systemImage: "bell.badge")
            }
            if prefs.remindersOn {
                DatePicker(
                    "Remind me at",
                    selection: Binding(
                        get: {
                            Calendar.current.date(bySettingHour: prefs.reminderHour, minute: prefs.reminderMinute, second: 0, of: .now) ?? .now
                        },
                        set: { date in
                            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                            model.setPreferences {
                                $0.reminderHour = c.hour ?? 18
                                $0.reminderMinute = c.minute ?? 0
                            }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        } header: {
            Text("Goals & reminders")
        } footer: {
            Text("Reach your daily goal to grow your 🔥 streak. The reminder skips days you've already hit it.")
        }
    }
}
