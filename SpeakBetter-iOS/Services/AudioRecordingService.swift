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
    
    // Audio level history for visualization
    private var audioLevelHistory: [Float] = []
    private let maxHistoryItems = 50
    
    // Publishers
    private let recordingStatusSubject = PassthroughSubject<Bool, Never>()
    var recordingStatus: AnyPublisher<Bool, Never> {
        return recordingStatusSubject.eraseToAnyPublisher()
    }
    
    private let audioLevelsSubject = PassthroughSubject<AudioLevelData, Never>()
    var audioLevels: AnyPublisher<AudioLevelData, Never> {
        return audioLevelsSubject.eraseToAnyPublisher()
    }
    
    // Audio level monitoring timer
    private var levelMonitorTimer: Timer?
    
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
        
        // Configure recording settings for high quality
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
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
                
                // Reset audio level history
                audioLevelHistory.removeAll()
                
                // Start monitoring audio levels
                startAudioLevelMonitoring()
                
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
        
        // Stop level monitoring
        stopAudioLevelMonitoring()
        
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
    
    // Start monitoring audio levels at regular intervals
    private func startAudioLevelMonitoring() {
        // Stop any existing timer
        stopAudioLevelMonitoring()
        
        // Create a new timer that fires 20 times per second
        levelMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioLevels()
        }
    }
    
    // Stop monitoring audio levels
    private func stopAudioLevelMonitoring() {
        levelMonitorTimer?.invalidate()
        levelMonitorTimer = nil
    }
    
    // Update and publish audio levels
    private func updateAudioLevels() {
        guard let recorder = audioRecorder else {
            return
        }
        
        // Update meters to get current values
        recorder.updateMeters()
        
        // Get power values
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // Convert from dB to a normalized value (dB values are typically negative)
        // -160 dB (very quiet) to 0 dB (maximum)
        let normalizedAverage = 1.0 + (averagePower / 160.0) // Will be in 0 to 1 range
        
        // Add to history, keeping the size limited
        audioLevelHistory.append(averagePower)
        if audioLevelHistory.count > maxHistoryItems {
            audioLevelHistory.removeFirst()
        }
        
        // Calculate whether the current level is above speaking threshold
        let isSpeaking = averagePower > -25.0 // Typical threshold for speech vs background noise
        
        // Create and publish the audio level data
        let levelData = AudioLevelData(
            averagePower: averagePower,
            peakPower: peakPower,
            normalizedValue: Float(normalizedAverage),
            isSpeaking: isSpeaking,
            levelHistory: audioLevelHistory
        )
        
        audioLevelsSubject.send(levelData)
    }
    
    // Get current audio levels for visualization (for direct polling)
    func getAudioLevels() -> Float {
        guard let recorder = audioRecorder else {
            return 0.0
        }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Convert to normalized value
        return 1.0 + (averagePower / 160.0)
    }
    
    // Get complete audio metrics
    func getAudioMetrics() -> AudioLevelData? {
        guard let recorder = audioRecorder else {
            return nil
        }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        let normalizedAverage = 1.0 + (averagePower / 160.0)
        let isSpeaking = averagePower > -25.0
        
        return AudioLevelData(
            averagePower: averagePower,
            peakPower: peakPower,
            normalizedValue: Float(normalizedAverage),
            isSpeaking: isSpeaking,
            levelHistory: audioLevelHistory
        )
    }
}

// Audio level data structure
struct AudioLevelData {
    let averagePower: Float    // Raw dB value, typically negative
    let peakPower: Float       // Raw dB peak value
    let normalizedValue: Float // 0.0 to 1.0 range
    let isSpeaking: Bool       // Whether current level is likely speech
    let levelHistory: [Float]  // Recent history of levels
}
