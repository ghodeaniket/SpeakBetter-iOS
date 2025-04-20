import Foundation
import Speech
import AVFoundation

class SpeechAnalysisService {
    // Future: This is where SFVoiceAnalytics would be implemented
    
    // Analyze speech using provided transcription and metrics
    func analyzeTranscription(_ transcription: String, metrics: [String: Any]) -> SpeechAnalysisResult {
        // Extract metrics
        let wordCount = metrics["wordCount"] as? Int ?? 0
        let wordsPerMinute = metrics["wordsPerMinute"] as? Double ?? 0
        let fillerWordCount = metrics["fillerWordCount"] as? Int ?? 0
        let fillerWords = metrics["fillerWords"] as? [String: Int] ?? [:]
        let duration = metrics["duration"] as? TimeInterval ?? 0
        
        // Evaluate pace
        let paceRating: String
        if wordsPerMinute < 120 {
            paceRating = "Too slow"
        } else if wordsPerMinute > 160 {
            paceRating = "Too fast"
        } else {
            paceRating = "Good"
        }
        
        // Evaluate filler words
        let fillerRatio = duration > 0 ? Double(fillerWordCount) / (duration / 60.0) : 0
        
        let fillerRating: String
        if fillerRatio < 2 {
            fillerRating = "Excellent"
        } else if fillerRatio < 5 {
            fillerRating = "Good"
        } else {
            fillerRating = "Needs improvement"
        }
        
        // Calculate overall score
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
        
        // Generate feedback points
        var feedbackPoints: [String] = []
        var suggestions: [String] = []
        
        // Pace feedback
        if paceRating == "Too slow" {
            feedbackPoints.append("Your speaking pace was slower than optimal at \(Int(wordsPerMinute)) words per minute.")
            suggestions.append("Try to increase your speaking pace slightly. Practice with a timer to develop a better sense of timing.")
        } else if paceRating == "Too fast" {
            feedbackPoints.append("Your speaking pace was faster than optimal at \(Int(wordsPerMinute)) words per minute.")
            suggestions.append("Try to slow down slightly. Taking brief pauses between thoughts can help regulate your pace.")
        } else {
            feedbackPoints.append("Your speaking pace was good at \(Int(wordsPerMinute)) words per minute.")
        }
        
        // Filler word feedback
        if fillerWordCount > 0 {
            let fillerList = fillerWords.map { "'\($0.key)' (\($0.value)x)" }.joined(separator: ", ")
            feedbackPoints.append("You used \(fillerWordCount) filler words: \(fillerList)")
            
            if fillerRating == "Needs improvement" {
                suggestions.append("Practice being comfortable with silence instead of using filler words. Try pausing when you would typically say a filler word.")
            }
        } else {
            feedbackPoints.append("Excellent job avoiding filler words!")
        }
        
        // Create speech data
        let speechData = SpeechData(
            transcription: transcription,
            wordsPerMinute: wordsPerMinute,
            fillerWordCount: fillerWordCount,
            fillerWords: fillerWords,
            durationInSeconds: duration
        )
        
        // Return analysis result
        return SpeechAnalysisResult(
            overallScore: score,
            paceRating: paceRating,
            fillerRating: fillerRating,
            feedbackPoints: feedbackPoints,
            suggestions: suggestions,
            speechData: speechData
        )
    }
    
    // Future: Add methods for SFVoiceAnalytics integration
}
