import Foundation
import Combine
import SwiftUI

class FeedbackViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var feedbackPoints: [FeedbackPoint] = []
    @Published var suggestions: [FeedbackPoint] = []
    @Published var isSpeakingFeedback: Bool = false
    @Published var currentlyHighlightedFeedback: FeedbackPoint?
    @Published var feedbackReadingCompleted: Bool = false
    
    // MARK: - Private Properties
    
    private let feedbackService = FeedbackService()
    private var cancellables = Set<AnyCancellable>()
    private var analysisResult: SpeechAnalysisResult?
    
    // MARK: - Initialization
    
    init() {
        // Subscribe to feedback service speaking state changes
        // This would be implemented if feedback service exposed such a publisher
    }
    
    // MARK: - Public Methods
    
    /// Process a new speech analysis result
    func processFeedback(from result: SpeechAnalysisResult) {
        self.analysisResult = result
        
        // Generate structured feedback
        let allFeedback = feedbackService.generateFeedback(from: result)
        
        // Separate feedback into observations and suggestions
        self.feedbackPoints = allFeedback.filter { !$0.isSuggestion }
        self.suggestions = allFeedback.filter { $0.isSuggestion }
        
        // Reset state
        self.feedbackReadingCompleted = false
        self.currentlyHighlightedFeedback = nil
    }
    
    /// Deliver vocal feedback
    func deliverVocalFeedback() {
        guard let result = analysisResult else { return }
        
        // Start speaking
        isSpeakingFeedback = true
        
        // Use feedback service to speak the feedback
        feedbackService.speakFeedback(from: result) { [weak self] in
            DispatchQueue.main.async {
                self?.isSpeakingFeedback = false
                self?.feedbackReadingCompleted = true
            }
        }
    }
    
    /// Speak a specific feedback point
    func speakFeedbackPoint(_ point: FeedbackPoint) {
        // Stop any current speech
        if isSpeakingFeedback {
            feedbackService.stopSpeaking()
        }
        
        // Highlight the current feedback point
        currentlyHighlightedFeedback = point
        isSpeakingFeedback = true
        
        // Speak the selected feedback
        feedbackService.speakFeedbackPoint(point) { [weak self] in
            DispatchQueue.main.async {
                self?.isSpeakingFeedback = false
                self?.currentlyHighlightedFeedback = nil
            }
        }
    }
    
    /// Stop speaking feedback
    func stopSpeaking() {
        if isSpeakingFeedback {
            feedbackService.stopSpeaking()
            isSpeakingFeedback = false
            currentlyHighlightedFeedback = nil
        }
    }
    
    /// Pause speaking feedback
    func pauseSpeaking() {
        if isSpeakingFeedback {
            feedbackService.pauseSpeaking { [weak self] in
                DispatchQueue.main.async {
                    self?.isSpeakingFeedback = false
                }
            }
        }
    }
    
    /// Resume speaking feedback
    func resumeSpeaking() {
        if !isSpeakingFeedback && feedbackService.isCurrentlySpeaking == false {
            feedbackService.continueSpeaking()
            isSpeakingFeedback = true
        }
    }
    
    /// Get feedback points for a specific category
    func getFeedbackForCategory(_ category: FeedbackCategory) -> [FeedbackPoint] {
        return feedbackPoints.filter { $0.category == category }
    }
    
    /// Get suggestions for a specific category
    func getSuggestionsForCategory(_ category: FeedbackCategory) -> [FeedbackPoint] {
        return suggestions.filter { $0.category == category }
    }
    
    /// Check if there is feedback for a specific category
    func hasFeedbackForCategory(_ category: FeedbackCategory) -> Bool {
        return !getFeedbackForCategory(category).isEmpty || !getSuggestionsForCategory(category).isEmpty
    }
    
    /// Get color for a feedback category based on the analysis result
    func colorForCategory(_ category: FeedbackCategory) -> Color {
        guard let result = analysisResult else { return .blue }
        
        switch category {
        case .pace:
            return colorForRating(result.paceRating)
        case .fillerWords:
            return colorForRating(result.fillerRating)
        case .voiceQuality:
            return colorForRating(result.voiceQualityRating)
        case .pauses:
            return colorForRating(result.pauseRating)
        }
    }
    
    /// Returns top N feedback points by priority
    func getTopFeedback(count: Int = 3) -> [FeedbackPoint] {
        let prioritizedFeedback = feedbackPoints.sorted { $0.priority > $1.priority }
        return Array(prioritizedFeedback.prefix(count))
    }
    
    // MARK: - Helper Methods
    
    private func colorForRating(_ rating: String) -> Color {
        switch rating {
        case "Excellent", "Good", "Well varied", "Highly expressive", "Good use of pauses":
            return .green
        case "Average", "Somewhat varied", "Slightly too many pauses", "Few pauses", "Slightly slow", "Slightly fast":
            return .blue
        case "Too slow", "Too fast":
            return .yellow
        case "Needs improvement", "Poor", "Monotone", "Too many pauses":
            return .red
        default:
            return .primary
        }
    }
}
