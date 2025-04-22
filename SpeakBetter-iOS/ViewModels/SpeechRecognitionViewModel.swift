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
    private let feedbackService = FeedbackService()
    
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
        
        // Create a class to hold our analysis data that can be captured and modified by closures
        class AnalysisData {
            var transcription: String = ""
            var voiceAnalytics: [String: Any] = [:]
            var apiSpeakingRate: Double? = nil
        }
        
        // Create shared data object
        let analysisData = AnalysisData()
        if !transcription.isEmpty {
            analysisData.transcription = transcription
        }
        
        // Create a dispatch group to synchronize multiple analysis tasks
        let analysisGroup = DispatchGroup()
        
        // 1. Get speech transcription (if not already available)
        if transcription.isEmpty {
            analysisGroup.enter()
            speechRecognitionService.recognizeSpeechFromFile(url: recordingURL) { [weak self, analysisData] result in
                defer { analysisGroup.leave() }
                
                switch result {
                case .success(let (text, speakingRate)):
                    DispatchQueue.main.async {
                        self?.transcription = text
                        analysisData.transcription = text
                        
                        // Store speaking rate if available
                        if let speakingRate = speakingRate {
                            analysisData.apiSpeakingRate = speakingRate
                        }
                    }
                case .failure(let error):
                    print("Transcription error: \(error.localizedDescription)")
                }
            }
        }
        
        // 2. Analyze voice characteristics using SFVoiceAnalytics
        analysisGroup.enter()
        voiceAnalyticsService.analyzeVoiceCharacteristics(from: recordingURL) { [analysisData] result in
            defer { analysisGroup.leave() }
            
            switch result {
            case .success(let data):
                analysisData.voiceAnalytics = data
            case .failure(let error):
                print("Voice analytics error: \(error.localizedDescription)")
            }
        }
        
        // 3. Detect pauses in the audio
        analysisGroup.enter()
        DispatchQueue.global().async { [weak self, analysisData] in
            guard let self = self else { analysisGroup.leave(); return }
            
            let pauses = self.speechAnalysisService.detectPauses(from: recordingURL)
            analysisData.voiceAnalytics["longPauses"] = pauses
            
            analysisGroup.leave()
        }
        
        // When all analysis tasks are complete, generate the final result
        analysisGroup.notify(queue: .main) { [weak self, analysisData] in
            guard let self = self else { return }
            
            // Make sure we have the latest transcription
            let finalTranscription = self.transcription.isEmpty ? analysisData.transcription : self.transcription
            
            // Analyze the speech using API metrics when available
            let words = finalTranscription.split(separator: " ").map { String($0) }
            let wordCount = words.count
            
            // Count filler words (using a more comprehensive list from the analysis service)
            var fillerWordCount = 0
            var fillerWordsMap: [String: Int] = [:]
            
            for word in words.map({ $0.lowercased() }) {
                if self.speechAnalysisService.fillerWords.contains(word) {
                    fillerWordCount += 1
                    fillerWordsMap[word, default: 0] += 1
                }
            }
            
            // Let the speech recognition service analyze the metrics
            // Pass the API speaking rate when available
            let basicMetrics = self.speechRecognitionService.analyzeSpeech(
                transcription: finalTranscription,
                duration: self.recordingDuration,
                apiSpeakingRate: analysisData.apiSpeakingRate
            )
            
            // Combine all metrics
            var metrics = basicMetrics
            metrics["fillerWordCount"] = fillerWordCount
            metrics["fillerWords"] = fillerWordsMap
            metrics["duration"] = self.recordingDuration
            
            // If API provided a speaking rate, add it to metrics
            if let apiRate = analysisData.apiSpeakingRate {
                metrics["apiSpeakingRate"] = apiRate
            }
            
            // Add voice analytics metrics
            metrics.merge(analysisData.voiceAnalytics) { (_, new) in new }
            
            // Add debugging info about WPM source
            if analysisData.apiSpeakingRate != nil {
                metrics["wpmSource"] = "Apple Speech API"
            } else {
                metrics["wpmSource"] = "Manual calculation"
            }
            
            // Generate the analysis result
            let result = self.speechAnalysisService.analyzeTranscription(
                finalTranscription,
                metrics: metrics,
                audioURL: recordingURL
            )
            
            // Update the UI
            DispatchQueue.main.async {
                self.analysisResult = result
                self.isAnalyzing = false
                
                // We'll wait a moment before offering voice feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.promptVoiceFeedback()
                }
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
    
    // MARK: - Voice Feedback
    
    /// Prompt user if they want to hear vocal feedback
    private func promptVoiceFeedback() {
        // This would typically show a UI alert or notification
        // For the POC, we could automatically start feedback for testing purposes
        // In a production app, we would ask the user before starting vocal feedback
        
        // For testing, we can automatically provide a brief vocal feedback on key metrics
        if let result = analysisResult {
            provideBriefVocalFeedback(result)
        }
    }
    
    /// Provide a brief vocal summary of the analysis
    func provideBriefVocalFeedback(_ result: SpeechAnalysisResult) {
        let feedbackText = "Your speaking score is \(result.overallScore) out of 100. " +
                          "You spoke at \(Int(result.speechData.wordsPerMinute)) words per minute, which is \(result.paceRating.lowercased()). " +
                          "I detected \(result.speechData.fillerWordCount) filler words."
        
        let utterance = AVSpeechUtterance(string: feedbackText)
        
        // Configure voice
        if let voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Samantha-premium") {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        // Configure parameters
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Speak feedback
        feedbackService.speakFeedbackPoint(
            FeedbackPoint(
                category: .pace,
                text: feedbackText,
                priority: 5
            )
        )
    }
    
    /// Provide full vocal feedback via FeedbackView
    func provideFullVocalFeedback() {
        guard let result = analysisResult else { return }
        
        // Generate structured feedback
        let _ = feedbackService.generateFeedback(from: result)
        
        // Speak the feedback
        feedbackService.speakFeedback(from: result)
    }
}
