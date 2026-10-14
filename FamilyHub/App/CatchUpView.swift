import FamilyHubCore
import SwiftUI

/// Record a short catch-up about a conversation — a 10-second recap of a call, or key moments of
/// the call itself on speakerphone — and turn it into a summary, a note for that person's profile,
/// and a checklist of anything you said you'd follow up on. See `RecordingService` for the
/// on-device speech-to-text and `CatchUpSummarizer` for the Claude calls.
struct CatchUpView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = RecordingService()
    @State private var note: CatchUpNote
    @State private var persisted = false
    @State private var isSummarizing = false
    @State private var errorText: String?
    @State private var question = ""
    @State private var answer: String?
    @State private var isAsking = false
    @State private var savedNote = false
    @State private var checkedItems: Set<Int> = []

    /// `personID` nil = the general entry point (Today tab); pick someone afterwards, or leave it unassigned.
    init(personID: UUID? = nil) {
        _note = State(initialValue: CatchUpNote(personID: personID))
    }

    private var person: Person? {
        guard let id = note.personID else { return nil }
        return model.person(id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("With", selection: Binding(get: { note.personID }, set: { setPerson($0) })) {
                        Text("Not assigned yet").tag(UUID?.none)
                        ForEach(model.sortedPeople) { p in
                            Text(p.name).tag(Optional(p.id))
                        }
                    }
                }

                Section {
                    recordingControls
                    if !note.transcript.isEmpty {
                        Text(note.transcript)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("What was said")
                } footer: {
                    if !recorder.usedOnDeviceRecognition {
                        Text("On-device transcription isn't available in this language right now, so this used Apple's speech service instead.")
                    } else {
                        Text("Tap record right after hanging up for a quick recap, or record key moments on speakerphone. Only the transcript is kept — the recording itself isn't saved.")
                    }
                }

                if let errorText {
                    Section {
                        Label(errorText, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !note.summary.isEmpty {
                    summarySection
                    if !note.actionItems.isEmpty { actionItemsSection }
                    askSection
                }
            }
            .navigationTitle("Catch-Up Recorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    @ViewBuilder private var recordingControls: some View {
        HStack(spacing: 12) {
            Button {
                Task { await toggleRecording() }
            } label: {
                Label(recorder.isRecording ? "Stop" : "Record", systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(recorder.isRecording ? .red : model.theme.accent)

            if recorder.isRecording {
                Text("Listening…").foregroundStyle(.secondary)
            } else if !note.transcript.isEmpty, note.summary.isEmpty {
                Button {
                    Task { await generateSummary() }
                } label: {
                    if isSummarizing { ProgressView() } else { Text("Generate Summary") }
                }
                .buttonStyle(.bordered)
                .disabled(isSummarizing || Keychain.apiKey == nil)
            }
            Spacer()
        }
    }

    @ViewBuilder private var summarySection: some View {
        Section("Summary") {
            Text(note.summary)
        }
        if !note.suggestedNote.isEmpty {
            Section("Note for their profile") {
                Text(note.suggestedNote)
                if savedNote {
                    Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else if let person {
                    Button("Save to \(person.firstName)'s profile") {
                        model.saveSuggestedNote(note.suggestedNote, to: person.id)
                        savedNote = true
                    }
                } else {
                    Text("Pick who this was with, above, to save it to their profile.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private var actionItemsSection: some View {
        Section("Follow up on") {
            ForEach(Array(note.actionItems.enumerated()), id: \.offset) { i, item in
                Button {
                    if checkedItems.contains(i) { checkedItems.remove(i) } else { checkedItems.insert(i) }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: checkedItems.contains(i) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(checkedItems.contains(i) ? model.theme.accent : .secondary)
                        Text(item)
                            .strikethrough(checkedItems.contains(i))
                            .foregroundStyle(checkedItems.contains(i) ? .secondary : .primary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var askSection: some View {
        Section("Ask about this conversation") {
            HStack {
                TextField("What did they say about…?", text: $question)
                Button("Ask") { Task { await askQuestion() } }
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || isAsking || Keychain.apiKey == nil)
            }
            if isAsking { ProgressView() }
            if let answer { Text(answer).foregroundStyle(.secondary) }
        }
    }

    // MARK: - Actions

    private func setPerson(_ id: UUID?) {
        note.personID = id
        if persisted { model.assignCatchUpNote(note.id, to: id) }
    }

    private func toggleRecording() async {
        if recorder.isRecording {
            note.transcript = recorder.stop()
        } else {
            errorText = nil
            do {
                try await recorder.start()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func generateSummary() async {
        guard let apiKey = Keychain.apiKey, !apiKey.isEmpty else {
            errorText = OpenerError.missingAPIKey.localizedDescription
            return
        }
        isSummarizing = true
        defer { isSummarizing = false }
        do {
            let summarizer = CatchUpSummarizer(apiKey: apiKey, model: Prefs.model)
            let result = try await summarizer.summarize(transcript: note.transcript, person: person)
            note.summary = result.summary
            note.suggestedNote = result.suggestedNote
            note.actionItems = result.actionItems
            errorText = nil
            if persisted {
                model.assignCatchUpNote(note.id, to: note.personID) // keep personID in sync if changed before this point
            } else {
                model.addCatchUpNote(note)
                persisted = true
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func askQuestion() async {
        guard let apiKey = Keychain.apiKey, !apiKey.isEmpty else {
            errorText = OpenerError.missingAPIKey.localizedDescription
            return
        }
        isAsking = true
        defer { isAsking = false }
        do {
            answer = try await CatchUpSummarizer.ask(question: question, transcript: note.transcript, apiKey: apiKey, model: Prefs.model)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
