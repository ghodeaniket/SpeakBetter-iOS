import Foundation
import Speech
import AVFoundation
import Combine

class VoiceAnalyticsService: NSObject, SFSpeechRecognitionTaskDelegate {
    // Publishers for analytics data
    private let analyticsSubject = PassthroughSubject<[String: Any], Error>()
    var analyticsPublisher: AnyPublisher<[String: Any], Error> {
        return analyticsSubject.eraseToAnyPublisher()
    }
    
    // Analysis state
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var analysisInProgress = false
    private var fileAnalysisCompletion: ((Result<[String: Any], Error>) -> Void)?
    
    override init() {
        // Initialize with US English locale
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
    }
    
    // MARK: - SFSpeechRecognitionTaskDelegate
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        // We only care about final results, so we ignore interim transcriptions
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition result: SFSpeechRecognitionResult) {
        // Extract analytics from the result
        var analyticsData = processVoiceAnalytics(from: result)
        
        // Add transcription for reference
        analyticsData["transcription"] = result.bestTranscription.formattedString
        
        // Publish analytics data or complete file analysis
        if analysisInProgress {
            analyticsSubject.send(analyticsData)
        } else if let completion = fileAnalysisCompletion {
            completion(.success(analyticsData))
            fileAnalysisCompletion = nil
        }
    }
    
    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        if let completion = fileAnalysisCompletion {
            completion(.failure(NSError(
                domain: "VoiceAnalyticsService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Recognition task was cancelled"]
            )))
            fileAnalysisCompletion = nil
        }
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        if !successfully {
            let error = NSError(
                domain: "VoiceAnalyticsService",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Recognition task failed"]
            )
            
            if analysisInProgress {
                analyticsSubject.send(completion: .failure(error))
            } else if let completion = fileAnalysisCompletion {
                completion(.failure(error))
                fileAnalysisCompletion = nil
            }
        }
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
        
        // Cancel any existing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Store completion handler
        fileAnalysisCompletion = completion
        analysisInProgress = false
        
        // Create recognition request from audio file
        let request = SFSpeechURLRecognitionRequest(url: url)
        
        // Configure for on-device recognition
        request.requiresOnDeviceRecognition = true
        
        // Start recognition task with self as delegate
        recognitionTask = recognizer.recognitionTask(with: request, delegate: self)
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
        
        // Configure for on-device recognition
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        
        // Set state for real-time analysis
        analysisInProgress = true
        fileAnalysisCompletion = nil
        
        // Start recognition task with self as delegate
        recognitionTask = recognizer.recognitionTask(with: request, delegate: self)
        
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
