import Foundation
import Combine
import AVFoundation
import Speech
import UIKit

class SpeechRecognitionViewModel: ObservableObject {
    // Published properties that the View can observe
    @Published var isRecording = false
    @Published var transcription = ""
    @Published var showPermissionAlert = false
    @Published var analysisResult: SpeechAnalysisResult?
    @Published var audioLevel: CGFloat = 0.0           // Simple audio level (0.0-1.0 range)
    @Published var currentAudioData: AudioLevelData?   // Detailed audio level data
    @Published var isAnalyzing = false
    
    // Services
    private let audioRecordingService = AudioRecordingService()
    private let speechRecognitionService = SpeechRecognitionService()
    private let speechAnalysisService = SpeechAnalysisService()
    private let voiceAnalyticsService = VoiceAnalyticsService()
    
    // Private properties
    private var cancellables = Set<AnyCancellable>()
    private var audioLevelTimer: Timer?
    private var recordingURL: URL?
    private var startTime: Date?
    private var recordingDuration: TimeInterval = 0
    
    // Initialize
    init() {
        setupSubscriptions()
    }
    
    // Set up Combine subscriptions
    private func setupSubscriptions() {
        // Subscribe to recording status changes
        audioRecordingService.recordingStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] isRecording in
                self?.isRecording = isRecording
                
                if isRecording {
                    self?.startAudioLevelMonitoring()
                } else {
                    self?.stopAudioLevelMonitoring()
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to transcription updates
        speechRecognitionService.transcriptionPublisher
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] transcription in
                    self?.transcription = transcription
                }
            )
            .store(in: &cancellables)
    }
    
    // Check for speech recognition and microphone permissions
    func checkPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    // Also check microphone permission
                    self?.checkMicrophonePermission()
                default:
                    self?.showPermissionAlert = true
                }
            }
        }
    }
    
    private func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            break // We're good to go
        case .denied:
            self.showPermissionAlert = true
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                if !granted {
                    DispatchQueue.main.async {
                        self?.showPermissionAlert = true
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    // Start recording and recognizing speech
    func startRecording() {
        // Start audio recording
        recordingURL = audioRecordingService.startRecording()
        
        // Start speech recognition
        speechRecognitionService.startLiveRecognition()
        
        // Record start time
        startTime = Date()
    }
    
    // Stop recording and analyze results
    func stopRecording() {
        // Stop speech recognition
        speechRecognitionService.stopLiveRecognition()
        
        // Stop audio recording
        if let url = audioRecordingService.stopRecording() {
            recordingURL = url
        }
        
        // Calculate recording duration
        if let startTime = startTime {
            recordingDuration = Date().timeIntervalSince(startTime)
        }
        
        // Start analysis process
        analyzeRecording()
    }
    
    // Analyze the recorded speech
    private func analyzeRecording() {
        guard let recordingURL = recordingURL else {
            print("No recording URL available")
            return
        }
        
        // Set analyzing flag
        isAnalyzing = true
        
        // Create a dispatch group to synchronize multiple analysis tasks
        let analysisGroup = DispatchGroup()
        
        // 1. Get speech transcription (if not already available)
        if transcription.isEmpty {
            analysisGroup.enter()
            speechRecognitionService.recognizeSpeechFromFile(url: recordingURL) { [weak self] result in
                defer { analysisGroup.leave() }
                
                switch result {
                case .success(let text):
                    DispatchQueue.main.async {
                        self?.transcription = text
                    }
                case .failure(let error):
                    print("Transcription error: \(error.localizedDescription)")
                }
            }
        }
        
        // 2. Analyze voice characteristics using SFVoiceAnalytics
        var voiceAnalytics: [String: Any] = [:]
        analysisGroup.enter()
        voiceAnalyticsService.analyzeVoiceCharacteristics(from: recordingURL) { result in
            defer { analysisGroup.leave() }
            
            switch result {
            case .success(let data):
                voiceAnalytics = data
            case .failure(let error):
                print("Voice analytics error: \(error.localizedDescription)")
            }
        }
        
        // 3. Detect pauses in the audio
        analysisGroup.enter()
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { analysisGroup.leave(); return }
            
            let pauses = self.speechAnalysisService.detectPauses(from: recordingURL)
            voiceAnalytics["longPauses"] = pauses
            
            analysisGroup.leave()
        }
        
        // When all analysis tasks are complete, generate the final result
        analysisGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Analyze the speech using collected metrics
            let words = self.transcription.split(separator: " ").map { String($0) }
            let wordCount = words.count
            
            // Calculate speech metrics
            let wordsPerMinute = self.recordingDuration > 0 ? 
                Double(wordCount) / (self.recordingDuration / 60.0) : 0
            
            // Count filler words (using a more comprehensive list from the analysis service)
            var fillerWordCount = 0
            var fillerWordsMap: [String: Int] = [:]
            
            for word in words.map({ $0.lowercased() }) {
                if self.speechAnalysisService.fillerWords.contains(word) {
                    fillerWordCount += 1
                    fillerWordsMap[word, default: 0] += 1
                }
            }
            
            // Combine all metrics
            var metrics: [String: Any] = [
                "wordCount": wordCount,
                "wordsPerMinute": wordsPerMinute,
                "fillerWordCount": fillerWordCount,
                "fillerWords": fillerWordsMap,
                "duration": self.recordingDuration
            ]
            
            // Add voice analytics metrics
            metrics.merge(voiceAnalytics) { (_, new) in new }
            
            // Generate the analysis result
            let result = self.speechAnalysisService.analyzeTranscription(
                self.transcription,
                metrics: metrics,
                audioURL: recordingURL
            )
            
            // Update the UI
            DispatchQueue.main.async {
                self.analysisResult = result
                self.isAnalyzing = false
            }
        }
    }
    
    // Audio level monitoring for visualization
    private func startAudioLevelMonitoring() {
        // Subscribe to detailed audio level data
        audioRecordingService.audioLevels
            .receive(on: RunLoop.main)
            .sink { [weak self] audioData in
                guard let self = self else { return }
                self.audioLevel = CGFloat(audioData.normalizedValue)
                self.currentAudioData = audioData
            }
            .store(in: &cancellables)
            
        // Fallback timer-based polling in case the publisher isn't available
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.currentAudioData == nil else { return }
            
            // Get audio metrics
            if let audioMetrics = self.audioRecordingService.getAudioMetrics() {
                DispatchQueue.main.async {
                    self.audioLevel = CGFloat(audioMetrics.normalizedValue)
                    self.currentAudioData = audioMetrics
                }
            } else {
                // Fallback to basic level
                let level = self.audioRecordingService.getAudioLevels()
                
                DispatchQueue.main.async {
                    self.audioLevel = CGFloat(level)
                }
            }
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        DispatchQueue.main.async {
            self.audioLevel = 0.0
            self.currentAudioData = nil
        }
    }
}
