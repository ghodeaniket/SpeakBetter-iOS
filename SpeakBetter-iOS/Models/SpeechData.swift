import Foundation

struct SpeechData {
    var transcription: String
    var wordsPerMinute: Double
    var fillerWordCount: Int
    var fillerWords: [String: Int]  // Map of filler word to count
    var durationInSeconds: TimeInterval
    
    // Voice analytics metrics (from SFVoiceAnalytics)
    var jitter: Double?
    var shimmer: Double?
    var pitch: Double?
    
    init(transcription: String = "",
         wordsPerMinute: Double = 0.0,
         fillerWordCount: Int = 0,
         fillerWords: [String: Int] = [:],
         durationInSeconds: TimeInterval = 0.0,
         jitter: Double? = nil,
         shimmer: Double? = nil,
         pitch: Double? = nil) {
        
        self.transcription = transcription
        self.wordsPerMinute = wordsPerMinute
        self.fillerWordCount = fillerWordCount
        self.fillerWords = fillerWords
        self.durationInSeconds = durationInSeconds
        self.jitter = jitter
        self.shimmer = shimmer
        self.pitch = pitch
    }
}

// Analysis results that will be presented to the user
struct SpeechAnalysisResult {
    let overallScore: Int
    let paceRating: String  // "Too slow", "Good", "Too fast"
    let fillerRating: String  // "Excellent", "Good", "Needs improvement"
    let feedbackPoints: [String]
    let suggestions: [String]
    
    var speechData: SpeechData
}
