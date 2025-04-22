import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognitionService: NSObject, SFSpeechRecognitionTaskDelegate {
    // Publishers for recognition results
    private let transcriptionSubject = PassthroughSubject<String, Error>()
    var transcriptionPublisher: AnyPublisher<String, Error> {
        return transcriptionSubject.eraseToAnyPublisher()
    }
    
    private let recognitionStatusSubject = PassthroughSubject<Bool, Never>()
    var recognitionStatus: AnyPublisher<Bool, Never> {
        return recognitionStatusSubject.eraseToAnyPublisher()
    }
    
    // Speech recognition properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    // Properties for file-based recognition
    private var fileRecognitionCompletion: ((Result<(String, Double?), Error>) -> Void)?
    private var currentRecognitionMode: RecognitionMode = .live
    
    // Recognition modes
    private enum RecognitionMode {
        case live
        case file
    }
    
    // Initialize service
    override init() {
        super.init()
    }
    
    // MARK: - SFSpeechRecognitionTaskDelegate methods
    
    // Called when recognition task produces interim results
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        switch currentRecognitionMode {
        case .live:
            transcriptionSubject.send(transcription.formattedString)
        case .file:
            // For file recognition, we only care about final results
            break
        }
    }
    
    // Called when recognition completes with final result
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        let transcription = recognitionResult.bestTranscription.formattedString
        
        // Calculate speaking rate manually from the transcription and duration
        // In iOS 18, we need to calculate manually as the direct metadata access has changed
        var speakingRate: Double? = nil
        
        // Calculate duration from segments if available
        if let firstSegment = recognitionResult.bestTranscription.segments.first,
           let lastSegment = recognitionResult.bestTranscription.segments.last {
            
            let duration = lastSegment.timestamp + lastSegment.duration - firstSegment.timestamp
            if duration > 0 {
                let words = transcription.split(separator: " ").count
                // Convert to words per minute
                speakingRate = Double(words) / (duration / 60.0)
                print("Calculated speaking rate from segments: \(speakingRate ?? 0) WPM")
            }
        } else {
            print("No segments available to calculate speaking rate")
        }
        
        switch currentRecognitionMode {
        case .live:
            transcriptionSubject.send(transcription)
        case .file:
            if let completion = fileRecognitionCompletion {
                completion(.success((transcription, speakingRate)))
                fileRecognitionCompletion = nil
            }
        }
    }
    
    // Called when task is canceled
    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        switch currentRecognitionMode {
        case .live:
            recognitionStatusSubject.send(false)
        case .file:
            if let completion = fileRecognitionCompletion {
                completion(.failure(NSError(
                    domain: "SpeechRecognitionService",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Recognition task was cancelled"]
                )))
                fileRecognitionCompletion = nil
            }
        }
    }
    
    // Called when there's an error
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        if !successfully {
            let error = NSError(
                domain: "SpeechRecognitionService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Recognition task failed"]
            )
            
            switch currentRecognitionMode {
            case .live:
                transcriptionSubject.send(completion: .failure(error))
                recognitionStatusSubject.send(false)
            case .file:
                if let completion = fileRecognitionCompletion {
                    completion(.failure(error))
                    fileRecognitionCompletion = nil
                }
            }
        } else if currentRecognitionMode == .live {
            recognitionStatusSubject.send(false)
        }
    }
    
    // Start real-time speech recognition
    func startLiveRecognition() {
        // Verify availability
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            transcriptionSubject.send(completion: .failure(NSError(domain: "SpeechRecognitionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not available"])))
            return
        }
        
        // Check for existing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            transcriptionSubject.send(completion: .failure(error))
            return
        }
        
        // Set up recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            transcriptionSubject.send(completion: .failure(NSError(domain: "SpeechRecognitionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])))
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Set up audio engine
        audioEngine = AVAudioEngine()
        
        let inputNode = audioEngine?.inputNode
        
        // Install tap on input node
        let recordingFormat = inputNode?.outputFormat(forBus: 0)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Prepare and start audio engine
        audioEngine?.prepare()
        
        do {
            try audioEngine?.start()
            recognitionStatusSubject.send(true)
        } catch {
            transcriptionSubject.send(completion: .failure(error))
            return
        }
        // Set recognition mode to live
        currentRecognitionMode = .live
        
        // Start recognition task using delegate
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, delegate: self)
    }
    
    // Stop real-time recognition
    func stopLiveRecognition() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        recognitionStatusSubject.send(false)
    }
    
    // Recognize speech from audio file
    func recognizeSpeechFromFile(url: URL, completion: @escaping (Result<(String, Double?), Error>) -> Void) {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let speechRecognizer = recognizer, speechRecognizer.isAvailable else {
            completion(.failure(NSError(domain: "SpeechRecognitionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not available"])))
            return
        }
        
        // Cancel any existing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Set mode and store the completion handler
        currentRecognitionMode = .file
        fileRecognitionCompletion = completion
        
        // Create and configure the request
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        // Start recognition with self as delegate
        recognitionTask = speechRecognizer.recognitionTask(with: request, delegate: self)
    }
    
    // Analyze speech for specific metrics
    func analyzeSpeech(transcription: String, duration: TimeInterval, apiSpeakingRate: Double? = nil) -> [String: Any] {
        var metrics: [String: Any] = [:]
        
        // Count words
        let words = transcription.split(separator: " ")
        metrics["wordCount"] = words.count
        
        // Calculate words per minute
        // Use API-provided speaking rate if available, otherwise calculate manually
        let wordsPerMinute: Double
        if let apiRate = apiSpeakingRate {
            wordsPerMinute = apiRate
            print("Using API-provided speaking rate in analyzeSpeech: \(apiRate) WPM")
        } else {
            // Fall back to manual calculation
            let minutes = duration / 60.0
            wordsPerMinute = minutes > 0 ? Double(words.count) / minutes : 0
            print("Using manually calculated speaking rate in analyzeSpeech: \(wordsPerMinute) WPM")
        }
        metrics["wordsPerMinute"] = wordsPerMinute
        
        // Count filler words
        let fillerWords = ["um", "uh", "like", "so", "you know", "actually", "basically", "literally", "right"]
        let lowerWords = words.map { String($0).lowercased() }
        
        var fillerCount = 0
        var fillerWordMap: [String: Int] = [:]
        
        for word in lowerWords {
            if fillerWords.contains(word) {
                fillerCount += 1
                fillerWordMap[word, default: 0] += 1
            }
        }
        
        metrics["fillerWordCount"] = fillerCount
        metrics["fillerWords"] = fillerWordMap
        
        // Future: Add SFVoiceAnalytics metrics here
        
        return metrics
    }
}
