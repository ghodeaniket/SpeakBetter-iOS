import Foundation
import AVFoundation
import Speech
import Combine

class AudioRecordingService {
    // Audio recording properties
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var recordingURL: URL?
    
    // Recording session details
    private var startTime: Date?
    private var recordingDuration: TimeInterval = 0
    
    // Publisher for recording status
    private let recordingStatusSubject = PassthroughSubject<Bool, Never>()
    var recordingStatus: AnyPublisher<Bool, Never> {
        return recordingStatusSubject.eraseToAnyPublisher()
    }
    
    // Initialize the service
    init() {
        setupRecordingDirectory()
    }
    
    // Set up the recording directory
    private func setupRecordingDirectory() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDirectory = documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
        
        // Create recordings directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: recordingsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create recordings directory: \(error.localizedDescription)")
            }
        }
    }
    
    // Start recording audio
    func startRecording() -> URL? {
        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            return nil
        }
        
        // Create recording URL
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDirectory = documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        let url = recordingsDirectory.appendingPathComponent(fileName)
        
        // Configure recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // Set up audio recorder
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            if audioRecorder?.record() == true {
                startTime = Date()
                recordingURL = url
                recordingStatusSubject.send(true)
                return url
            }
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // Stop recording and return the recording URL
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, let url = recordingURL else {
            return nil
        }
        
        // Calculate recording duration
        if let startTime = startTime {
            recordingDuration = Date().timeIntervalSince(startTime)
        }
        
        // Stop recording
        recorder.stop()
        
        // Reset state
        audioRecorder = nil
        startTime = nil
        recordingStatusSubject.send(false)
        
        return url
    }
    
    // Get recording duration
    func getRecordingDuration() -> TimeInterval {
        return recordingDuration
    }
    
    // Get audio levels for visualization
    func getAudioLevels() -> Float {
        guard let recorder = audioRecorder else {
            return 0.0
        }
        
        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }
}
