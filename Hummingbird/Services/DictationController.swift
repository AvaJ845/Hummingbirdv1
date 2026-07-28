import AVFoundation
import Foundation
import Observation
import Speech
import SwiftUI

/// On-device speech recognition for ticker / coin dictation.
@MainActor
@Observable
final class DictationController {
    enum Phase: Equatable {
        case idle
        case blooming
        case listening
        case confirming
        case collapsing
    }

    private(set) var phase: Phase = .idle
    private(set) var transcript = ""
    private(set) var partialTranscript = ""
    private(set) var errorMessage: String?
    private(set) var bloomProgress: CGFloat = 0
    /// Icon rotation in degrees — animates send → checkmark.
    private(set) var actionRotation: Double = 0

    var isActive: Bool {
        phase != .idle
    }

    var displayText: String {
        let live = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return transcript
    }

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    func start() async {
        errorMessage = nil
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Dictation isn't available on this device."
            return
        }

        do {
            try await ensureAuthorized()
            try beginAudioSession()
            try beginRecognition(with: recognizer)
            await animateIn()
        } catch {
            stopEngine()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            await animateOut()
        }
    }

    /// Stops listening and returns a cleaned symbol candidate.
    func confirm() async -> String {
        phase = .confirming
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            actionRotation = 360
        }
        let text = sanitizedSymbol(from: displayText)
        stopEngine()
        try? await Task.sleep(nanoseconds: 220_000_000)
        await animateOut()
        transcript = ""
        partialTranscript = ""
        return text
    }

    func cancel() async {
        stopEngine()
        transcript = ""
        partialTranscript = ""
        await animateOut()
    }

    // MARK: - Animation

    private func animateIn() async {
        phase = .blooming
        actionRotation = 0
        withAnimation(.spring(response: 0.58, dampingFraction: 0.86)) {
            bloomProgress = 1
            actionRotation = 180
        }
        try? await Task.sleep(nanoseconds: 320_000_000)
        guard phase == .blooming else { return }
        phase = .listening
    }

    private func animateOut() async {
        phase = .collapsing
        withAnimation(.spring(response: 0.48, dampingFraction: 0.9)) {
            bloomProgress = 0
            actionRotation = 0
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        phase = .idle
    }

    // MARK: - Permissions & engine

    private func ensureAuthorized() async throws {
        let speech = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speech == .authorized else {
            throw DictationError.speechDenied
        }

        let mic = await AVAudioApplication.requestRecordPermission()
        guard mic else { throw DictationError.microphoneDenied }
    }

    private func beginAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func beginRecognition(with recognizer: SFSpeechRecognizer) throws {
        stopEngine()

        // Privacy: only ever recognize on-device — refuse rather than stream audio
        // to Apple's servers if on-device recognition isn't available.
        guard recognizer.supportsOnDeviceRecognition else {
            throw DictationError.onDeviceUnavailable
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.partialTranscript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.transcript = result.bestTranscription.formattedString
                    }
                }
                if error != nil, self.audioEngine.isRunning == false {
                    // Engine already torn down — ignore.
                }
            }
        }
    }

    private func stopEngine() {
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Prefer the last spoken token; strip punctuation.
    func sanitizedSymbol(from raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "[^A-Za-z0-9\\-\\s]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let token = cleaned.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? cleaned
        return token
    }
}

enum DictationError: LocalizedError {
    case speechDenied
    case microphoneDenied
    case onDeviceUnavailable

    var errorDescription: String? {
        switch self {
        case .speechDenied:
            "Speech recognition access is required for dictation. Enable it in Settings."
        case .microphoneDenied:
            "Microphone access is required for dictation. Enable it in Settings."
        case .onDeviceUnavailable:
            "Dictation needs on-device speech recognition, which isn't available here. Type the symbol instead — your audio never leaves your device."
        }
    }
}
