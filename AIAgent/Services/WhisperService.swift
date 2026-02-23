import AVFoundation
import Foundation

@MainActor
@Observable
final class WhisperService: NSObject {
    var isRecording = false
    var isTranscribing = false
    var error: String?

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("voice_input.m4a")
    }

    func startRecording() {
        error = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            self.error = "Audio session error: \(error.localizedDescription)"
            return
        }

        // Check mic permission
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] allowed in
                Task { @MainActor in
                    if allowed {
                        self?.beginRecording()
                    } else {
                        self?.error = "Microphone access denied"
                    }
                }
            }
        case .denied:
            error = "Microphone access denied. Enable it in Settings."
        case .granted:
            beginRecording()
        @unknown default:
            error = "Unknown microphone permission state"
        }
    }

    private func beginRecording() {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            self.error = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() async -> String? {
        guard let recorder = audioRecorder, recorder.isRecording else { return nil }

        recorder.stop()
        isRecording = false
        audioRecorder = nil

        // Transcribe
        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let text = try await transcribe(fileURL: recordingURL)
            // Clean up
            try? FileManager.default.removeItem(at: recordingURL)
            return text
        } catch {
            self.error = "Transcription failed: \(error.localizedDescription)"
            return nil
        }
    }

    func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        try? FileManager.default.removeItem(at: recordingURL)
    }

    // MARK: - Whisper API

    private func transcribe(fileURL: URL) async throws -> String {
        let apiKey = Config.apiKey
        guard !apiKey.isEmpty else {
            throw NSError(domain: "Whisper", code: 0, userInfo: [NSLocalizedDescriptionKey: "No API key set"])
        }

        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)

        var body = Data()
        // Model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        // End
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let raw = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Whisper", code: 1, userInfo: [NSLocalizedDescriptionKey: "API error: \(raw)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw NSError(domain: "Whisper", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        return text
    }
}
