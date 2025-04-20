import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognitionService {
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
    
    // Initialize service
    init() {}
    
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
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.audioEngine?.stop()
                self.audioEngine?.inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.recognitionStatusSubject.send(false)
                self.transcriptionSubject.send(completion: .failure(error))
                return
            }
            
            if let result = result {
                self.transcriptionSubject.send(result.bestTranscription.formattedString)
            }
        }
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
    func recognizeSpeechFromFile(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let speechRecognizer = recognizer, speechRecognizer.isAvailable else {
            completion(.failure(NSError(domain: "SpeechRecognitionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not available"])))
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        speechRecognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let result = result {
                completion(.success(result.bestTranscription.formattedString))
            }
        }
    }
    
    // Analyze speech for specific metrics
    func analyzeSpeech(transcription: String, duration: TimeInterval) -> [String: Any] {
        var metrics: [String: Any] = [:]
        
        // Count words
        let words = transcription.split(separator: " ")
        metrics["wordCount"] = words.count
        
        // Calculate words per minute
        let minutes = duration / 60.0
        let wordsPerMinute = minutes > 0 ? Double(words.count) / minutes : 0
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
