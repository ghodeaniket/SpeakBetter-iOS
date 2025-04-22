import Foundation
import AVFoundation

// Enum that defines different feedback categories
enum FeedbackCategory: String, CaseIterable {
    case pace = "Pace"
    case fillerWords = "Filler Words"
    case voiceQuality = "Voice Quality"
    case pauses = "Pauses"
    
    var icon: String {
        switch self {
        case .pace: return "speedometer"
        case .fillerWords: return "textformat.abc"
        case .voiceQuality: return "waveform"
        case .pauses: return "pause.circle"
        }
    }
}

// Represents a single feedback point with prioritization
struct FeedbackPoint: Identifiable {
    let id = UUID()
    let category: FeedbackCategory
    let text: String
    let priority: Int // 1-5, with 5 being highest
    let isSuggestion: Bool
    
    init(category: FeedbackCategory, text: String, priority: Int = 3, isSuggestion: Bool = false) {
        self.category = category
        self.text = text
        self.priority = priority
        self.isSuggestion = isSuggestion
    }
}

class FeedbackService: NSObject {
    // MARK: - Properties
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var feedbackPoints: [FeedbackPoint] = []
    private var currentUtterance: AVSpeechUtterance?
    private var isSpeaking = false
    private var pauseHandler: (() -> Void)?
    private var completionHandler: (() -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }
    
    // MARK: - Feedback Generation
    
    /// Generates feedback based on speech analysis result
    func generateFeedback(from result: SpeechAnalysisResult) -> [FeedbackPoint] {
        var feedback: [FeedbackPoint] = []
        
        // Process pace feedback
        feedback.append(contentsOf: generatePaceFeedback(result))
        
        // Process filler words feedback
        feedback.append(contentsOf: generateFillerWordsFeedback(result))
        
        // Process voice quality feedback
        feedback.append(contentsOf: generateVoiceQualityFeedback(result))
        
        // Process pauses feedback
        feedback.append(contentsOf: generatePausesFeedback(result))
        
        // Add result suggestions as feedback points
        for suggestion in result.suggestions {
            let category = determineCategoryForSuggestion(suggestion)
            feedback.append(FeedbackPoint(
                category: category,
                text: suggestion, 
                priority: 4,
                isSuggestion: true
            ))
        }
        
        // Store feedback for later use
        self.feedbackPoints = feedback
        
        return feedback
    }
    
    private func generatePaceFeedback(_ result: SpeechAnalysisResult) -> [FeedbackPoint] {
        var feedback: [FeedbackPoint] = []
        
        // Convert existing feedback points to structured feedback
        if let paceFeedback = result.feedbackPoints.first(where: { $0.contains("speaking pace") }) {
            let priority: Int
            
            switch result.paceRating {
            case "Too slow", "Too fast":
                priority = 5
            case "Slightly slow", "Slightly fast":
                priority = 4
            case "Good":
                priority = 2
            default:
                priority = 3
            }
            
            feedback.append(FeedbackPoint(
                category: .pace,
                text: paceFeedback,
                priority: priority
            ))
        }
        
        return feedback
    }
    
    private func generateFillerWordsFeedback(_ result: SpeechAnalysisResult) -> [FeedbackPoint] {
        var feedback: [FeedbackPoint] = []
        
        // Convert existing feedback points to structured feedback
        if let fillerFeedback = result.feedbackPoints.first(where: { $0.contains("filler word") }) {
            let priority: Int
            
            switch result.fillerRating {
            case "Poor":
                priority = 5
            case "Needs improvement":
                priority = 4
            case "Average":
                priority = 3
            case "Good":
                priority = 2
            case "Excellent":
                priority = 1
            default:
                priority = 3
            }
            
            feedback.append(FeedbackPoint(
                category: .fillerWords,
                text: fillerFeedback,
                priority: priority
            ))
        }
        
        return feedback
    }
    
    private func generateVoiceQualityFeedback(_ result: SpeechAnalysisResult) -> [FeedbackPoint] {
        var feedback: [FeedbackPoint] = []
        
        // Convert existing feedback points to structured feedback
        if let voiceFeedback = result.feedbackPoints.first(where: { 
            $0.contains("voice pitch") || $0.contains("vocal variety") 
        }) {
            let priority: Int
            
            switch result.voiceQualityRating {
            case "Monotone":
                priority = 4
            case "Somewhat varied":
                priority = 3
            case "Well varied":
                priority = 2
            case "Highly expressive":
                priority = 1
            default:
                priority = 3
            }
            
            feedback.append(FeedbackPoint(
                category: .voiceQuality,
                text: voiceFeedback,
                priority: priority
            ))
        }
        
        return feedback
    }
    
    private func generatePausesFeedback(_ result: SpeechAnalysisResult) -> [FeedbackPoint] {
        var feedback: [FeedbackPoint] = []
        
        // Convert existing feedback points to structured feedback
        if let pauseFeedback = result.feedbackPoints.first(where: { $0.contains("pause") }) {
            let priority: Int
            
            switch result.pauseRating {
            case "Too many pauses":
                priority = 4
            case "Slightly too many pauses":
                priority = 3
            case "Few pauses":
                priority = 3
            case "Good use of pauses":
                priority = 1
            default:
                priority = 3
            }
            
            feedback.append(FeedbackPoint(
                category: .pauses,
                text: pauseFeedback,
                priority: priority
            ))
        }
        
        return feedback
    }
    
    // Helper to determine category for a suggestion
    private func determineCategoryForSuggestion(_ suggestion: String) -> FeedbackCategory {
        let suggestion = suggestion.lowercased()
        
        if suggestion.contains("pace") || suggestion.contains("speak") || suggestion.contains("faster") || suggestion.contains("slower") {
            return .pace
        } else if suggestion.contains("filler") || suggestion.contains("um") || suggestion.contains("uh") {
            return .fillerWords
        } else if suggestion.contains("voice") || suggestion.contains("pitch") || suggestion.contains("tone") || suggestion.contains("inflection") {
            return .voiceQuality
        } else if suggestion.contains("pause") {
            return .pauses
        }
        
        // Default to filler words as this is common issue
        return .fillerWords
    }
    
    // MARK: - Feedback Prioritization
    
    /// Returns feedback points ordered by priority
    func getPrioritizedFeedback() -> [FeedbackPoint] {
        return feedbackPoints.sorted { $0.priority > $1.priority }
    }
    
    /// Returns top N feedback points by priority
    func getTopFeedback(count: Int = 3) -> [FeedbackPoint] {
        return Array(getPrioritizedFeedback().prefix(count))
    }
    
    /// Returns all suggestions ordered by priority
    func getSuggestions() -> [FeedbackPoint] {
        return feedbackPoints.filter { $0.isSuggestion }.sorted { $0.priority > $1.priority }
    }
    
    // MARK: - Text-to-Speech Feedback
    
    /// Speak the feedback using AVSpeechSynthesizer
    func speakFeedback(from result: SpeechAnalysisResult, completion: (() -> Void)? = nil) {
        // Generate coaching introduction
        let intro = "Thank you for your speech. Here's my feedback."
        
        // Get top 3 feedback points
        let prioritizedFeedback = getTopFeedback(count: 3)
        
        // Get top suggestion if available
        let topSuggestion = getSuggestions().first
        
        // Construct full feedback text
        var feedbackText = intro
        
        // Add positive reinforcement
        if result.overallScore >= 80 {
            feedbackText += " Overall, you did very well."
        } else if result.overallScore >= 60 {
            feedbackText += " You've done a good job, with some areas to improve."
        } else {
            feedbackText += " I've identified some areas where you can improve."
        }
        
        // Add specific feedback points
        for point in prioritizedFeedback {
            feedbackText += " \(point.text)"
        }
        
        // Add a suggestion if available
        if let suggestion = topSuggestion {
            feedbackText += " Here's a tip: \(suggestion.text)"
        }
        
        // Add encouraging closing
        feedbackText += " Keep practicing, and you'll continue to improve."
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: feedbackText)
        
        // Configure voice and properties
        configureUtterance(utterance)
        
        // Store the completion handler
        self.completionHandler = completion
        
        // Speak the feedback
        self.currentUtterance = utterance
        speechSynthesizer.speak(utterance)
        isSpeaking = true
    }
    
    /// Speak a specific feedback point
    func speakFeedbackPoint(_ point: FeedbackPoint, completion: (() -> Void)? = nil) {
        let utterance = AVSpeechUtterance(string: point.text)
        configureUtterance(utterance)
        
        self.completionHandler = completion
        self.currentUtterance = utterance
        speechSynthesizer.speak(utterance)
        isSpeaking = true
    }
    
    /// Configure speech utterance properties
    private func configureUtterance(_ utterance: AVSpeechUtterance) {
        // Choose a high-quality voice (US English female)
        if let voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Samantha-premium") {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        // Configure speech parameters for more natural speaking
        utterance.rate = 0.5         // 0.0 (slowest) to 1.0 (fastest)
        utterance.pitchMultiplier = 1.0  // 0.5 (lowest) to 2.0 (highest)
        utterance.volume = 1.0       // 0.0 (silent) to 1.0 (loudest)
        
        // Add slight pause between sentences for more natural sound
        utterance.postUtteranceDelay = 0.5
    }
    
    /// Stop speaking feedback
    func stopSpeaking() {
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }
    }
    
    /// Pause speaking feedback
    func pauseSpeaking(handler: (() -> Void)? = nil) {
        if isSpeaking {
            speechSynthesizer.pauseSpeaking(at: .word)
            pauseHandler = handler
        }
    }
    
    /// Continue speaking feedback
    func continueSpeaking() {
        if !isSpeaking && currentUtterance != nil {
            speechSynthesizer.continueSpeaking()
            isSpeaking = true
        }
    }
    
    /// Check if feedback is currently being spoken
    var isCurrentlySpeaking: Bool {
        return isSpeaking
    }
    
    // MARK: - Advanced Feedback Utilities
    
    /// Generate personalized coaching advice based on performance trends
    func generatePersonalizedAdvice(historicalResults: [SpeechAnalysisResult]) -> [String] {
        // This would use more sophisticated logic in a full implementation
        // For the POC, we'll return some placeholder advice
        var advice: [String] = []
        
        if historicalResults.count >= 2 {
            // Look for trends in the most recent sessions
            let recentResults = Array(historicalResults.suffix(3))
            
            // Check for consistent issues with pace
            let paceIssues = recentResults.filter { $0.paceRating != "Good" }.count
            if paceIssues >= 2 {
                advice.append("I've noticed you consistently struggle with speaking pace. Try practicing with a metronome to develop a better rhythm.")
            }
            
            // Check for improvement in filler words
            if let first = recentResults.first, let last = recentResults.last {
                if last.fillerScore > first.fillerScore && last.fillerScore - first.fillerScore > 10 {
                    advice.append("Great job reducing your use of filler words! Keep practicing conscious pausing instead of using fillers.")
                }
            }
        }
        
        // Add general advice if we don't have specific trend-based suggestions
        if advice.isEmpty {
            advice.append("Keep practicing regularly. The key to improvement is consistent practice with mindful attention to areas that need work.")
        }
        
        return advice
    }
    
    /// Add variety to feedback by generating alternative phrasings
    func generateAlternativePhrasing(for feedback: String) -> String {
        // For the POC, just return the original
        // In a full implementation, this would use an AI system to generate varied phrasings
        return feedback
    }
    
    /// Build a coaching dialogue for interactive feedback
    func buildCoachingDialogue(from result: SpeechAnalysisResult) -> [String] {
        // In a full implementation, this would create a more natural coaching conversation
        // For the POC, we'll create a simple sequence of statements
        
        var dialogue: [String] = []
        
        // Introduction
        dialogue.append("Hi there! I've analyzed your speech and I'm ready to share some insights.")
        
        // Overall assessment
        if result.overallScore >= 85 {
            dialogue.append("First, I want to say that your overall delivery was excellent! You scored \(result.overallScore) out of 100.")
        } else if result.overallScore >= 70 {
            dialogue.append("Overall, you did quite well in your delivery. You scored \(result.overallScore) out of 100.")
        } else {
            dialogue.append("I've identified some areas where you can improve. Your overall score was \(result.overallScore) out of 100.")
        }
        
        // Specific feedback points
        let topFeedback = getTopFeedback(count: 2)
        for point in topFeedback {
            dialogue.append(point.text)
        }
        
        // Add a suggestion
        if let suggestion = getSuggestions().first {
            dialogue.append("Here's something specific you could try: \(suggestion.text)")
        }
        
        // Encouraging close
        dialogue.append("Would you like to hear more detail about any particular aspect of your speech?")
        
        return dialogue
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension FeedbackService: AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        isSpeaking = false
        pauseHandler?()
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        currentUtterance = nil
        completionHandler?()
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        currentUtterance = nil
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // This method could be used to highlight text as it's being spoken
        // Not needed for the POC but would be useful for a full implementation
    }
}
