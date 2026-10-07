import AVFoundation
import Foundation
import Observation
import Speech

/// Records audio in the foreground and transcribes it live, on-device where the current locale
/// supports it. No audio file is ever kept — only the transcript text is read by callers, which is
/// what gets persisted (cheaper storage, and it avoids storing raw family audio on disk).
@MainActor
@Observable
final class RecordingService {
    enum RecordingError: LocalizedError {
        case micPermissionDenied
        case speechPermissionDenied
        case recognizerUnavailable
        case audioEngineFailed(String)

        var errorDescription: String? {
            switch self {
            case .micPermissionDenied:
                return "Family Hub needs microphone access to record a catch-up. Turn it on in Settings."
            case .speechPermissionDenied:
                return "Family Hub needs speech recognition access to transcribe the recording. Turn it on in Settings."
            case .recognizerUnavailable:
                return "Speech recognition isn't available on this device right now."
            case let .audioEngineFailed(detail):
                return "Couldn't start recording (\(detail))."
            }
        }
    }

    private(set) var isRecording = false
    /// Updated live as speech is recognized; the final value becomes the transcript once stopped.
    private(set) var transcript = ""
    /// False once on-device recognition wasn't available for the current locale and transcription
    /// fell back to Apple's network speech recognizer (still never raw audio leaving the device
    /// to Family Hub itself — just the same path Siri dictation already uses elsewhere in iOS).
    private(set) var usedOnDeviceRecognition = true

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Starts recording and live transcription. Throws if the user denies microphone or speech
    /// permission, or if no recognizer is available at all.
    func start() async throws {
        guard !isRecording else { return }
        transcript = ""

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else { throw RecordingError.micPermissionDenied }

        let speechStatus = await Self.requestSpeechAuthorization()
        guard speechStatus == .authorized else { throw RecordingError.speechPermissionDenied }

        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(),
              recognizer.isAvailable else {
            throw RecordingError.recognizerUnavailable
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw RecordingError.audioEngineFailed(error.localizedDescription)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            usedOnDeviceRecognition = true
        } else {
            // No on-device model for this locale — fall back to the network recognizer rather than
            // failing outright.
            request.requiresOnDeviceRecognition = false
            usedOnDeviceRecognition = false
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            recognitionRequest = nil
            throw RecordingError.audioEngineFailed(error.localizedDescription)
        }

        isRecording = true
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.stopEngineOnly()
                }
            }
        }
    }

    /// Stops recording and returns the final transcript text. No audio file is written or kept.
    @discardableResult
    func stop() -> String {
        stopEngineOnly()
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
        return transcript
    }

    private func stopEngineOnly() {
        guard isRecording else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRecording = false
    }

    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
