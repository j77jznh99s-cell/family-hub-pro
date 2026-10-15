import FamilyHubCore
import SwiftUI

/// Record a short catch-up about a conversation — a 10-second recap of a call, or key moments of
/// the call itself on speakerphone — and turn it into a summary, a note for that person's profile,
/// and a checklist of anything you said you'd follow up on. See `RecordingService` for the
/// on-device speech-to-text and `CatchUpSummarizer` for the Claude calls.
///
/// The transcript is saved as soon as recording stops, before any Claude call, so a failed summary or a
/// missing API key never loses it; the summary is added to the same note later (retry from "Earlier catch-ups").
struct CatchUpView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = RecordingService()
    @State private var note: CatchUpNote
    @State private var persisted = false
    /// The note the current/last recording belongs to; a late transcript update only ever lands on that note.
    @State private var recordingNoteID: UUID?
    @State private var isSummarizing = false
    @State private var errorText: String?
    @State private var question = ""
    @State private var answer: String?
    @State private var isAsking = false
    @State private var savedNote = false
    /// Which saved notes "Earlier catch-ups" lists: this person's, or everyone's from the general entry point.
    private let filterPersonID: UUID?

    /// `personID` nil = the general entry point (Today tab); pick someone afterwards, or leave it unassigned.
    init(personID: UUID? = nil) {
        _note = State(initialValue: CatchUpNote(personID: personID))
        filterPersonID = personID
    }

    private var person: Person? {
        guard let id = note.personID else { return nil }
        return model.person(id)
    }

    private var earlierNotes: [CatchUpNote] {
        Array(
            model.catchUpNotes
                .filter { $0.id != note.id && (filterPersonID == nil || $0.personID == filterPersonID) }
                .prefix(20)
        )
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

                if persisted, note.needsSummary, !recorder.isRecording {
                    Section {
                        Label(
                            Keychain.apiKey == nil
                                ? "Transcript saved. Add a Claude API key in the Me tab to summarise it — it'll be under Earlier catch-ups."
                                : "Transcript saved. You can summarise it now, or later from Earlier catch-ups.",
                            systemImage: "tray.and.arrow.down"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

                earlierSection
            }
            .navigationTitle("Catch-Up Recorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            // Recognition can end on its own (a time limit or an error), and the final words can arrive just
            // after Stop: save whatever transcript exists whenever the recorder isn't running.
            .onChange(of: recorder.isRecording) { _, isRecording in
                if !isRecording { captureTranscript(recorder.transcript) }
            }
            .onChange(of: recorder.transcript) { _, text in
                if !recorder.isRecording { captureTranscript(text) }
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
            } else if note.needsSummary {
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
                let checked = note.isActionItemChecked(i)
                Button {
                    setActionItem(i, checked: !checked)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: checked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(checked ? model.theme.accent : .secondary)
                        Text(item)
                            .strikethrough(checked)
                            .foregroundStyle(checked ? .secondary : .primary)
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

    /// Saved catch-ups (newest first); tap one to reopen it — e.g. to summarise a transcript saved without one.
    @ViewBuilder private var earlierSection: some View {
        let notes = earlierNotes
        if !recorder.isRecording, !notes.isEmpty {
            Section("Earlier catch-ups") {
                ForEach(notes) { saved in
                    Button {
                        open(saved)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(saved.summary.isEmpty ? saved.transcript : saved.summary)
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                            HStack(spacing: 6) {
                                if saved.needsSummary { Text("Not summarised yet") }
                                if filterPersonID == nil, let id = saved.personID, let p = model.person(id) {
                                    Text(p.firstName)
                                }
                                if saved.createdAt != .distantPast {
                                    Text(saved.createdAt, format: .dateTime.month().day())
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", role: .destructive) { model.deleteCatchUpNote(saved.id) }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func setPerson(_ id: UUID?) {
        note.personID = id
        if persisted { model.assignCatchUpNote(note.id, to: id) }
    }

    private func setActionItem(_ index: Int, checked: Bool) {
        note.setActionItem(index, checked: checked)
        if persisted { model.setCatchUpActionItem(note.id, index: index, checked: checked) }
    }

    /// Shows a saved note in place of the current one (the current one is already saved, if it has a transcript).
    private func open(_ saved: CatchUpNote) {
        note = saved
        persisted = true
        recordingNoteID = nil
        resetConversationState()
    }

    private func resetConversationState() {
        errorText = nil
        question = ""
        answer = nil
        savedNote = false
    }

    private func toggleRecording() async {
        if recorder.isRecording {
            captureTranscript(recorder.stop())
        } else {
            errorText = nil
            do {
                try await recorder.start()
                // A new recording never overwrites one that's already saved: it starts a fresh note, same person.
                if !note.transcript.isEmpty {
                    note = CatchUpNote(personID: note.personID)
                    persisted = false
                    resetConversationState()
                }
                recordingNoteID = note.id
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    /// Saves the transcript straight away (before any Claude call), so it survives a failed summary or no API key.
    /// Only transcript text is stored — never audio.
    private func captureTranscript(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard note.id == recordingNoteID, !trimmed.isEmpty, trimmed != note.transcript else { return }
        note.transcript = trimmed
        model.saveCatchUpNote(note)
        persisted = true
    }

    private func generateSummary() async {
        guard let apiKey = Keychain.apiKey, !apiKey.isEmpty else {
            errorText = OpenerError.missingAPIKey.localizedDescription
            return
        }
        let target = note
        isSummarizing = true
        defer { isSummarizing = false }
        do {
            let summarizer = CatchUpSummarizer(apiKey: apiKey, model: Prefs.model)
            let result = try await summarizer.summarize(transcript: target.transcript, person: person)
            // Apply to the latest copy of that note: another note may have been opened while this was running.
            var updated = model.catchUpNotes.first { $0.id == target.id } ?? target
            updated.applySummary(summary: result.summary, suggestedNote: result.suggestedNote, actionItems: result.actionItems)
            model.saveCatchUpNote(updated)
            if note.id == target.id {
                note = updated
                persisted = true
                errorText = nil
            }
        } catch {
            if note.id == target.id { errorText = error.localizedDescription }
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
