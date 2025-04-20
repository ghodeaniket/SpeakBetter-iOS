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
    
    // Private properties
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    private var startTime: Date?
    private var recordingDuration: TimeInterval = 0
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    // Common filler words to detect
    private let fillerWords = ["um", "uh", "like", "so", "you know", "actually", "basically", "literally", "right"]
    
    init() {
        // Initial setup
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
        // Reset any previous recording
        resetRecording()
        
        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            return
        }
        
        // Set up audio engine and request
        audioEngine = AVAudioEngine()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let audioEngine = audioEngine,
              let recognitionRequest = recognitionRequest,
              let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            print("Speech recognition not available")
            return
        }
        
        // Configure recognition request
        recognitionRequest.shouldReportPartialResults = true
        
        // Set up recording URL for later analysis
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsDirectory.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        
        // Start recording
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Prepare and start audio engine
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            startTime = Date()
            isRecording = true
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
            resetRecording()
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcription = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                self.audioEngine?.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
    }
    
    // Stop recording and analyze results
    func stopRecording() {
        // Calculate recording duration
        if let startTime = startTime {
            recordingDuration = Date().timeIntervalSince(startTime)
        }
        
        // Stop audio engine and recognition task
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        
        // Reset recording state
        isRecording = false
        
        // Perform analysis on the transcription
        analyzeTranscription()
    }
    
    // Reset recording state
    private func resetRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        startTime = nil
        recordingDuration = 0
    }
    
    // Analyze the transcribed speech
    private func analyzeTranscription() {
        // For now, implement a simple analysis
        // This would be expanded with SFVoiceAnalytics in a later phase
        let words = transcription.split(separator: " ").map { String($0).lowercased() }
        
        // Count total words
        let totalWords = words.count
        
        // Calculate words per minute
        let minutes = recordingDuration / 60.0
        let wordsPerMinute = minutes > 0 ? Double(totalWords) / minutes : 0
        
        // Count filler words
        var fillerWordCount = 0
        var fillerWordsMap: [String: Int] = [:]
        
        for word in words {
            if fillerWords.contains(word) {
                fillerWordCount += 1
                fillerWordsMap[word, default: 0] += 1
            }
        }
        
        // Create speech data
        let speechData = SpeechData(
            transcription: transcription,
            wordsPerMinute: wordsPerMinute,
            fillerWordCount: fillerWordCount,
            fillerWords: fillerWordsMap,
            durationInSeconds: recordingDuration
        )
        
        // Generate feedback
        generateFeedback(for: speechData)
    }
    
    // Generate feedback based on speech analysis
    private func generateFeedback(for speechData: SpeechData) {
        // Pace rating
        let paceRating: String
        if speechData.wordsPerMinute < 120 {
            paceRating = "Too slow"
        } else if speechData.wordsPerMinute > 160 {
            paceRating = "Too fast"
        } else {
            paceRating = "Good"
        }
        
        // Filler word rating
        let fillerRatio = speechData.durationInSeconds > 0 ? 
            Double(speechData.fillerWordCount) / speechData.durationInSeconds * 60 : 0
        
        let fillerRating: String
        if fillerRatio < 2 {
            fillerRating = "Excellent"
        } else if fillerRatio < 5 {
            fillerRating = "Good"
        } else {
            fillerRating = "Needs improvement"
        }
        
        // Overall score (simple algorithm for POC)
        var score = 100
        
        // Deduct for pace
        if paceRating != "Good" {
            score -= 20
        }
        
        // Deduct for filler words
        if fillerRating == "Good" {
            score -= 10
        } else if fillerRating == "Needs improvement" {
            score -= 30
        }
        
        // Feedback points
        var feedbackPoints: [String] = []
        var suggestions: [String] = []
        
        // Add pace feedback
        if paceRating == "Too slow" {
            feedbackPoints.append("Your speaking pace was slower than optimal at \(Int(speechData.wordsPerMinute)) words per minute.")
            suggestions.append("Try to increase your speaking pace slightly. Practice with a timer to develop a better sense of timing.")
        } else if paceRating == "Too fast" {
            feedbackPoints.append("Your speaking pace was faster than optimal at \(Int(speechData.wordsPerMinute)) words per minute.")
            suggestions.append("Try to slow down slightly. Taking brief pauses between thoughts can help regulate your pace.")
        } else {
            feedbackPoints.append("Your speaking pace was good at \(Int(speechData.wordsPerMinute)) words per minute.")
        }
        
        // Add filler word feedback
        if speechData.fillerWordCount > 0 {
            let fillerList = speechData.fillerWords.map { "'\($0.key)' (\($0.value)x)" }.joined(separator: ", ")
            feedbackPoints.append("You used \(speechData.fillerWordCount) filler words: \(fillerList)")
            
            if fillerRating == "Needs improvement" {
                suggestions.append("Practice being comfortable with silence instead of using filler words. Try pausing when you would typically say a filler word.")
            }
        } else {
            feedbackPoints.append("Excellent job avoiding filler words!")
        }
        
        // Create and publish analysis result
        let result = SpeechAnalysisResult(
            overallScore: score,
            paceRating: paceRating,
            fillerRating: fillerRating,
            feedbackPoints: feedbackPoints,
            suggestions: suggestions,
            speechData: speechData
        )
        
        DispatchQueue.main.async {
            self.analysisResult = result
        }
    }
}
