#if os(iOS) || os(visionOS)
import AVFoundation
import Foundation
import Speech
import SpeechCore

/// Captures English audio for an explicitly on-device Apple Speech request.
///
/// Create one backend for the app's shared speech owner. The host must supply
/// microphone and speech usage descriptions before invoking authorization.
@MainActor
public final class AppleSpeechBackend: SpeechBackend {
    /// The locale-specific recognizer, absent when the locale is unsupported.
    private let recognizer: SFSpeechRecognizer?
    /// The sole engine owned by this backend.
    private var engine: AVAudioEngine?
    /// Observers scoped to the currently running recognition request.
    private var audioObservers: [NSObjectProtocol] = []
    /// The currently active audio request.
    private var request: SFSpeechAudioBufferRecognitionRequest?
    /// The currently active recognition task.
    private var recognitionTask: SFSpeechRecognitionTask?
    /// The bounded event producer for the current request.
    private var continuation: AsyncThrowingStream<SpeechEvent, Error>.Continuation?
    /// Whether this backend installed an input tap.
    private var hasTap = false
    /// Whether this backend activated the shared audio session.
    private var ownsAudioSession = false
    /// Identity used to discard delayed permission and termination callbacks.
    private var generation: UUID?

    /// Creates the English recognizer without requesting permission or capture.
    public init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    /// Whether the recognizer advertises on-device support.
    public var supportsOnDeviceRecognition: Bool {
        recognizer?.supportsOnDeviceRecognition == true
    }

    /// Requests speech and microphone permissions, stopping between prompts if invalidated.
    public func requestAuthorization() async -> Bool {
        let id = UUID()
        generation = id
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechAllowed, generation == id, !Task.isCancelled else { return false }
        let microphoneAllowed = await AVAudioApplication.requestRecordPermission()
        return microphoneAllowed && generation == id && !Task.isCancelled
    }

    /// Starts a bounded stream with cloud fallback explicitly disabled.
    public func startRecognition() throws -> AsyncThrowingStream<SpeechEvent, Error> {
        guard request == nil, let recognizer,
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw SpeechFailure.unavailable
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              AVAudioApplication.shared.recordPermission == .granted else {
            throw SpeechFailure.permissionDenied
        }
        let id = UUID()
        generation = id
        let pair = AsyncThrowingStream<SpeechEvent, Error>.makeStream(bufferingPolicy: .bufferingOldest(32))
        continuation = pair.continuation
        pair.continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == id else { return }
                self.stopRecognition()
            }
        }
        observeAudioChanges(for: pair.continuation)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
            ownsAudioSession = true
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            self.request = request
            let engine = AVAudioEngine()
            self.engine = engine
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw SpeechFailure.unavailable }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            hasTap = true
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    let event = SpeechEvent(text: result.bestTranscription.formattedString, isFinal: result.isFinal)
                    switch pair.continuation.yield(event) {
                    case .dropped:
                        pair.continuation.finish(throwing: SpeechFailure.overloaded)
                    case .terminated:
                        return
                    case .enqueued:
                        if result.isFinal { pair.continuation.finish() }
                    @unknown default:
                        pair.continuation.finish(throwing: SpeechFailure.recognitionFailed)
                    }
                }
                if error != nil { pair.continuation.finish(throwing: SpeechFailure.recognitionFailed) }
            }
            engine.prepare()
            try engine.start()
            return pair.stream
        } catch {
            stopRecognition()
            throw (error as? SpeechFailure) ?? .recognitionFailed
        }
    }

    /// Routes interruptions to the current stream without calling the audio engine
    /// on the notification thread. A retained observer can only end its old stream.
    private func observeAudioChanges(for stream: AsyncThrowingStream<SpeechEvent, Error>.Continuation) {
        let center = NotificationCenter.default
        audioObservers = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { notification in
                let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    stream.finish(throwing: SpeechFailure.interrupted)
                }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { notification in
                guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }
                switch reason {
                case .oldDeviceUnavailable, .newDeviceAvailable, .noSuitableRouteForCategory, .routeConfigurationChange:
                    stream.finish(throwing: SpeechFailure.interrupted)
                default:
                    break
                }
            },
            center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil) { _ in
                stream.finish(throwing: SpeechFailure.interrupted)
            }
        ]
    }

    /// Invalidates callbacks, stops capture and releases all resources owned here.
    public func stopRecognition() {
        generation = nil
        for observer in audioObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        audioObservers.removeAll()
        engine?.stop()
        if hasTap {
            engine?.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        engine = nil
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        continuation?.finish()
        continuation = nil
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        }
    }
}
#endif
