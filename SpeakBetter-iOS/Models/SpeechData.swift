import Foundation

struct SpeechData {
    var transcription: String
    var wordsPerMinute: Double
    var fillerWordCount: Int
    var fillerWords: [String: Int]  // Map of filler word to count
    var durationInSeconds: TimeInterval
    var longPauses: [PauseData]     // Pauses > 2 seconds
    
    // Voice analytics metrics (from SFVoiceAnalytics)
    var jitter: Double?             // Pitch variation
    var shimmer: Double?            // Amplitude variation
    var pitch: Double?              // Average pitch in Hz 
    var pitchVariability: Double?   // Pitch standard deviation
    var voicingPercentage: Double?  // Percentage of speech that is voiced
    
    // Speech timeline for visualization
    var speechTimeline: [SpeechTimelineSegment]
    
    init(transcription: String = "",
         wordsPerMinute: Double = 0.0,
         fillerWordCount: Int = 0,
         fillerWords: [String: Int] = [:],
         durationInSeconds: TimeInterval = 0.0,
         longPauses: [PauseData] = [],
         jitter: Double? = nil,
         shimmer: Double? = nil,
         pitch: Double? = nil,
         pitchVariability: Double? = nil,
         voicingPercentage: Double? = nil,
         speechTimeline: [SpeechTimelineSegment] = []) {
        
        self.transcription = transcription
        self.wordsPerMinute = wordsPerMinute
        self.fillerWordCount = fillerWordCount
        self.fillerWords = fillerWords
        self.durationInSeconds = durationInSeconds
        self.longPauses = longPauses
        self.jitter = jitter
        self.shimmer = shimmer
        self.pitch = pitch
        self.pitchVariability = pitchVariability
        self.voicingPercentage = voicingPercentage
        self.speechTimeline = speechTimeline
    }
}

// Model for pause information
struct PauseData: Identifiable {
    let id = UUID()
    let startTime: TimeInterval
    let duration: TimeInterval
}

// Model for speech timeline visualization
struct SpeechTimelineSegment: Identifiable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let isFillerWord: Bool
    let pitch: Double?
    let volume: Double?
}

// Analysis results that will be presented to the user
struct SpeechAnalysisResult: Equatable {
    let overallScore: Int
    let paceRating: String          // "Too slow", "Good", "Too fast"
    let fillerRating: String        // "Excellent", "Good", "Needs improvement"
    let voiceQualityRating: String  // "Monotone", "Varied", "Highly expressive"
    let pauseRating: String         // "Too many pauses", "Good use of pauses", "Few pauses"
    let feedbackPoints: [String]
    let suggestions: [String]
    
    var speechData: SpeechData
    
    // Detailed metrics for different aspects
    var paceScore: Int              // 0-100
    var fillerScore: Int            // 0-100
    var voiceQualityScore: Int      // 0-100 
    var pauseScore: Int             // 0-100
    
    // Implement Equatable
    static func == (lhs: SpeechAnalysisResult, rhs: SpeechAnalysisResult) -> Bool {
        return lhs.overallScore == rhs.overallScore &&
               lhs.paceRating == rhs.paceRating &&
               lhs.fillerRating == rhs.fillerRating &&
               lhs.voiceQualityRating == rhs.voiceQualityRating &&
               lhs.pauseRating == rhs.pauseRating &&
               lhs.feedbackPoints == rhs.feedbackPoints &&
               lhs.suggestions == rhs.suggestions &&
               lhs.paceScore == rhs.paceScore &&
               lhs.fillerScore == rhs.fillerScore &&
               lhs.voiceQualityScore == rhs.voiceQualityScore &&
               lhs.pauseScore == rhs.pauseScore
        // Note: We're not comparing speechData since it might contain arrays that don't conform to Equatable
    }
}

// Make SpeechData conform to Equatable as well
extension SpeechData: Equatable {
    static func == (lhs: SpeechData, rhs: SpeechData) -> Bool {
        return lhs.transcription == rhs.transcription &&
               lhs.wordsPerMinute == rhs.wordsPerMinute &&
               lhs.fillerWordCount == rhs.fillerWordCount &&
               lhs.durationInSeconds == rhs.durationInSeconds &&
               lhs.pitch == rhs.pitch &&
               lhs.jitter == rhs.jitter &&
               lhs.shimmer == rhs.shimmer &&
               lhs.pitchVariability == rhs.pitchVariability &&
               lhs.voicingPercentage == rhs.voicingPercentage
        // Note: We're not comparing collections that might not conform to Equatable
    }
}

// Make PauseData and SpeechTimelineSegment conform to Equatable
extension PauseData: Equatable {
    static func == (lhs: PauseData, rhs: PauseData) -> Bool {
        return lhs.startTime == rhs.startTime && lhs.duration == rhs.duration
    }
}

extension SpeechTimelineSegment: Equatable {
    static func == (lhs: SpeechTimelineSegment, rhs: SpeechTimelineSegment) -> Bool {
        return lhs.text == rhs.text &&
               lhs.startTime == rhs.startTime &&
               lhs.endTime == rhs.endTime &&
               lhs.isFillerWord == rhs.isFillerWord &&
               lhs.pitch == rhs.pitch &&
               lhs.volume == rhs.volume
    }
}
