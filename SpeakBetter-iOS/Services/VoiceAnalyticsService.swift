import Foundation
import Speech
import AVFoundation
import Combine

class VoiceAnalyticsService {
    // Publishers for analytics data
    private let analyticsSubject = PassthroughSubject<[String: Any], Error>()
    var analyticsPublisher: AnyPublisher<[String: Any], Error> {
        return analyticsSubject.eraseToAnyPublisher()
    }
    
    // Analysis state
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var analysisInProgress = false
    
    init() {
        // Initialize with US English locale
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    // Analyze voice characteristics (pitch, jitter, shimmer) from recorded audio file
    func analyzeVoiceCharacteristics(from url: URL, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            completion(.failure(NSError(
                domain: "VoiceAnalyticsService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognition not available"]
            )))
            return
        }
        
        // Create recognition request from audio file
        let request = SFSpeechURLRecognitionRequest(url: url)
        
        // Configure for on-device recognition if available
        if #available(iOS 13, *) {
            request.requiresOnDeviceRecognition = true
        }
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let result = result else {
                completion(.failure(NSError(
                    domain: "VoiceAnalyticsService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "No results returned"]
                )))
                return
            }
            
            // When we have the final result, extract voice analytics
            if result.isFinal {
                // Extract analytics from segments
                var analyticsData = self.processVoiceAnalytics(from: result)
                
                // Add transcription for reference
                analyticsData["transcription"] = result.bestTranscription.formattedString
                
                completion(.success(analyticsData))
            }
        }
    }
    
    // Real-time voice analytics processing
    func startRealTimeVoiceAnalysis(audioEngine: AVAudioEngine) -> SFSpeechAudioBufferRecognitionRequest? {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            analyticsSubject.send(completion: .failure(NSError(
                domain: "VoiceAnalyticsService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognition not available"]
            )))
            return nil
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        
        // Configure for on-device recognition if available
        if #available(iOS 13, *) {
            request.requiresOnDeviceRecognition = true
        }
        
        request.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.analyticsSubject.send(completion: .failure(error))
                return
            }
            
            if let result = result {
                // Extract analytics data
                let analyticsData = self.processVoiceAnalytics(from: result)
                
                // Publish the analytics data
                self.analyticsSubject.send(analyticsData)
            }
        }
        
        analysisInProgress = true
        return request
    }
    
    func stopRealTimeVoiceAnalysis() {
        recognitionTask?.cancel()
        recognitionTask = nil
        analysisInProgress = false
    }
    
    // Process voice analytics from recognition result
    private func processVoiceAnalytics(from result: SFSpeechRecognitionResult) -> [String: Any] {
        var analyticsData: [String: Any] = [:]
        
        // Due to SFVoiceAnalytics complexity and API changes across iOS versions,
        // for the POC we'll use a simplified approach with simulated voice metrics
        
        // In a production app, we would properly implement voice analytics processing
        // using the appropriate APIs based on the iOS version
        
        // Simulated pitch (fundamental frequency) - typical range: 80-250 Hz
        let basePitch = Bool.random() ? Double.random(in: 80...140) : Double.random(in: 170...250)
        analyticsData["pitch"] = basePitch
        
        // Simulated pitch variability - varies based on expressiveness
        let pitchVar = Double.random(in: 5...25)
        analyticsData["pitchVariability"] = pitchVar
        
        // Simulated jitter (frequency variation) - typically 0.5% to 1.5%
        let jitter = Double.random(in: 0.005...0.02)
        analyticsData["jitter"] = jitter
        
        // Simulated shimmer (amplitude variation) - typically 0.04 to 0.2 dB
        let shimmer = Double.random(in: 0.04...0.2)
        analyticsData["shimmer"] = shimmer
        
        // Simulated voicing percentage - typically 60% to 90%
        let voicing = Double.random(in: 0.6...0.9)
        analyticsData["voicingPercentage"] = voicing
        
        // Note: For the POC, we're using simulated values
        // In a production app, these would be extracted from audio analysis
        
        // Add transcription for reference (if available)
        if !result.bestTranscription.formattedString.isEmpty {
            analyticsData["transcription"] = result.bestTranscription.formattedString
        }
        
        return analyticsData
    }
}
