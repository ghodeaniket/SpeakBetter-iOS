import Foundation
import Speech
import AVFoundation

class SpeechAnalysisService {
    // Common filler words to detect
    let fillerWords = [
        "um", "uh", "hmm", "like", "so", "you know", "actually", 
        "basically", "literally", "right", "well", "i mean", "you see", 
        "kind of", "sort of", "anyway", "anyhow"
    ]
    
    // Analyze speech using provided transcription and metrics
    func analyzeTranscription(_ transcription: String, metrics: [String: Any], audioURL: URL?) -> SpeechAnalysisResult {
        // Extract basic metrics
        let wordCount = metrics["wordCount"] as? Int ?? 0
        let wordsPerMinute = metrics["wordsPerMinute"] as? Double ?? 0
        let fillerWordCount = metrics["fillerWordCount"] as? Int ?? 0
        let fillerWords = metrics["fillerWords"] as? [String: Int] ?? [:]
        let duration = metrics["duration"] as? TimeInterval ?? 0
        let longPauses = metrics["longPauses"] as? [PauseData] ?? []
        
        // Extract voice analytics metrics
        let jitter = metrics["jitter"] as? Double
        let shimmer = metrics["shimmer"] as? Double
        let pitch = metrics["pitch"] as? Double
        let pitchVariability = metrics["pitchVariability"] as? Double
        let voicingPercentage = metrics["voicingPercentage"] as? Double
        let speechTimeline = metrics["speechTimeline"] as? [SpeechTimelineSegment] ?? []
        
        // 1. Evaluate pace
        let (paceRating, paceScore) = evaluatePace(wordsPerMinute: wordsPerMinute)
        
        // 2. Evaluate filler words
        let (fillerRating, fillerScore) = evaluateFillerWords(
            fillerWordCount: fillerWordCount,
            duration: duration,
            wordCount: wordCount
        )
        
        // 3. Evaluate voice quality (using voice analytics)
        let (voiceQualityRating, voiceQualityScore) = evaluateVoiceQuality(
            pitch: pitch,
            pitchVariability: pitchVariability,
            jitter: jitter,
            shimmer: shimmer
        )
        
        // 4. Evaluate pauses
        let (pauseRating, pauseScore) = evaluatePauses(
            longPauses: longPauses,
            duration: duration
        )
        
        // Calculate overall score (weighted average)
        let overallScore = calculateOverallScore(
            paceScore: paceScore,
            fillerScore: fillerScore,
            voiceQualityScore: voiceQualityScore,
            pauseScore: pauseScore
        )
        
        // Generate feedback and suggestions
        let (feedbackPoints, suggestions) = generateFeedback(
            transcription: transcription,
            wordsPerMinute: wordsPerMinute,
            paceRating: paceRating,
            fillerWordCount: fillerWordCount,
            fillerWords: fillerWords,
            fillerRating: fillerRating,
            voiceQualityRating: voiceQualityRating,
            pauseRating: pauseRating,
            longPauses: longPauses,
            pitch: pitch,
            pitchVariability: pitchVariability
        )
        
        // Create speech data
        let speechData = SpeechData(
            transcription: transcription,
            wordsPerMinute: wordsPerMinute,
            fillerWordCount: fillerWordCount,
            fillerWords: fillerWords,
            durationInSeconds: duration,
            longPauses: longPauses,
            jitter: jitter,
            shimmer: shimmer,
            pitch: pitch,
            pitchVariability: pitchVariability,
            voicingPercentage: voicingPercentage,
            speechTimeline: speechTimeline
        )
        
        // Return analysis result
        return SpeechAnalysisResult(
            overallScore: overallScore,
            paceRating: paceRating,
            fillerRating: fillerRating,
            voiceQualityRating: voiceQualityRating,
            pauseRating: pauseRating,
            feedbackPoints: feedbackPoints,
            suggestions: suggestions,
            speechData: speechData,
            paceScore: paceScore,
            fillerScore: fillerScore,
            voiceQualityScore: voiceQualityScore,
            pauseScore: pauseScore
        )
    }
    
    // Process audio file to detect pauses
    func detectPauses(from url: URL, minimumDuration: TimeInterval = 2.0) -> [PauseData] {
        var pauses: [PauseData] = []
        
        // Set up audio file for reading
        guard let audioFile = try? AVAudioFile(forReading: url),
              let format = AVAudioFormat(standardFormatWithSampleRate: audioFile.fileFormat.sampleRate, channels: 1) else {
            return pauses
        }
        
        // Read the entire file into a buffer
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioFile.length))
        
        do {
            try audioFile.read(into: buffer!)
            
            // Get frame data
            guard let floatChannelData = buffer?.floatChannelData else {
                return pauses
            }
            
            let frameLength = Int(buffer!.frameLength)
            let channelData = floatChannelData[0]
            
            // Variables for pause detection
            var isPause = false
            var pauseStartFrame: Int = 0
            let sampleRate = Float(audioFile.fileFormat.sampleRate)
            let silenceThreshold: Float = 0.02 // Adjust based on recording conditions
            let framesPerAnalysis = Int(sampleRate / 10) // Analyze in 100ms chunks
            
            // Analyze audio frames
            for frameIndex in stride(from: 0, to: frameLength, by: framesPerAnalysis) {
                let endFrame = min(frameIndex + framesPerAnalysis, frameLength)
                
                // Calculate RMS amplitude for this chunk
                var sumOfSquares: Float = 0.0
                for i in frameIndex..<endFrame {
                    sumOfSquares += channelData[i] * channelData[i]
                }
                let rms = sqrt(sumOfSquares / Float(endFrame - frameIndex))
                
                // Check if we're in a pause or speech
                if rms < silenceThreshold {
                    // We are in a silence/pause
                    if !isPause {
                        isPause = true
                        pauseStartFrame = frameIndex
                    }
                } else {
                    // We are in speech
                    if isPause {
                        let pauseDuration = TimeInterval(frameIndex - pauseStartFrame) / TimeInterval(sampleRate)
                        if pauseDuration >= minimumDuration {
                            let pauseStartTime = TimeInterval(pauseStartFrame) / TimeInterval(sampleRate)
                            pauses.append(PauseData(
                                startTime: TimeInterval(pauseStartTime),
                                duration: TimeInterval(pauseDuration)
                            ))
                        }
                        isPause = false
                    }
                }
            }
            
            // Check if we ended in a pause
            if isPause {
                let pauseDuration = TimeInterval(frameLength - pauseStartFrame) / TimeInterval(sampleRate)
                if pauseDuration >= minimumDuration {
                    let pauseStartTime = TimeInterval(pauseStartFrame) / TimeInterval(sampleRate)
                    pauses.append(PauseData(
                        startTime: TimeInterval(pauseStartTime),
                        duration: TimeInterval(pauseDuration)
                    ))
                }
            }
        } catch {
            print("Error reading audio file: \(error.localizedDescription)")
        }
        
        return pauses
    }
    
    // MARK: - Private Evaluation Methods
    
    private func evaluatePace(wordsPerMinute: Double) -> (String, Int) {
        // Optimal pace is typically between 120-160 wpm for presentations
        let paceRating: String
        let paceScore: Int
        
        if wordsPerMinute < 100 {
            paceRating = "Too slow"
            paceScore = 60
        } else if wordsPerMinute < 120 {
            paceRating = "Slightly slow"
            paceScore = 80
        } else if wordsPerMinute <= 160 {
            paceRating = "Good"
            paceScore = 100
        } else if wordsPerMinute <= 180 {
            paceRating = "Slightly fast"
            paceScore = 80
        } else {
            paceRating = "Too fast"
            paceScore = 60
        }
        
        return (paceRating, paceScore)
    }
    
    private func evaluateFillerWords(fillerWordCount: Int, duration: TimeInterval, wordCount: Int) -> (String, Int) {
        // Calculate fillers per minute and as percentage of total words
        let minutes = duration / 60.0
        let fillerRatio = minutes > 0 ? Double(fillerWordCount) / minutes : 0
        let fillerPercentage = wordCount > 0 ? (Double(fillerWordCount) / Double(wordCount)) * 100 : 0
        
        let fillerRating: String
        let fillerScore: Int
        
        if fillerRatio < 1 && fillerPercentage < 2 {
            fillerRating = "Excellent"
            fillerScore = 100
        } else if fillerRatio < 2 && fillerPercentage < 4 {
            fillerRating = "Good"
            fillerScore = 90
        } else if fillerRatio < 4 && fillerPercentage < 7 {
            fillerRating = "Average"
            fillerScore = 75
        } else if fillerRatio < 6 && fillerPercentage < 10 {
            fillerRating = "Needs improvement"
            fillerScore = 60
        } else {
            fillerRating = "Poor"
            fillerScore = 40
        }
        
        return (fillerRating, fillerScore)
    }
    
    private func evaluateVoiceQuality(pitch: Double?, pitchVariability: Double?, jitter: Double?, shimmer: Double?) -> (String, Int) {
        // Default values for missing metrics
        let voiceQualityRating: String
        let voiceQualityScore: Int
        
        // If we don't have voice analytics data, use neutral rating
        guard let pitchVariability = pitchVariability, 
              let jitter = jitter,
              let shimmer = shimmer else {
            return ("No voice data", 75)
        }
        
        // Evaluate pitch variability (monotone vs. expressive)
        // Higher pitch variability generally indicates more expressive speech
        if pitchVariability < 5 {
            voiceQualityRating = "Monotone"
            voiceQualityScore = 60
        } else if pitchVariability < 15 {
            voiceQualityRating = "Somewhat varied"
            voiceQualityScore = 75
        } else if pitchVariability < 25 {
            voiceQualityRating = "Well varied"
            voiceQualityScore = 90
        } else {
            voiceQualityRating = "Highly expressive"
            voiceQualityScore = 100
        }
        
        // Adjust score based on jitter and shimmer (lower is generally better for clarity)
        // but extremely low can sound artificial
        var scoreAdjustment = 0
        
        if jitter > 0.02 {
            scoreAdjustment -= 5
        }
        
        if shimmer > 0.1 {
            scoreAdjustment -= 5
        }
        
        return (voiceQualityRating, max(0, min(100, voiceQualityScore + scoreAdjustment)))
    }
    
    private func evaluatePauses(longPauses: [PauseData], duration: TimeInterval) -> (String, Int) {
        let pauseRating: String
        let pauseScore: Int
        
        // Calculate total pause time and frequency
        let totalPauseTime = longPauses.reduce(0.0) { $0 + $1.duration }
        let pausePercentage = duration > 0 ? (totalPauseTime / duration) * 100 : 0
        let pausesPerMinute = duration > 0 ? Double(longPauses.count) / (duration / 60.0) : 0
        
        // Evaluate pause usage
        if pausesPerMinute < 0.5 {
            pauseRating = "Few pauses"
            pauseScore = 70
        } else if pausesPerMinute <= 2 && pausePercentage <= 15 {
            pauseRating = "Good use of pauses"
            pauseScore = 100
        } else if pausesPerMinute <= 3 && pausePercentage <= 20 {
            pauseRating = "Slightly too many pauses"
            pauseScore = 80
        } else {
            pauseRating = "Too many pauses"
            pauseScore = 60
        }
        
        return (pauseRating, pauseScore)
    }
    
    private func calculateOverallScore(paceScore: Int, fillerScore: Int, voiceQualityScore: Int, pauseScore: Int) -> Int {
        // Weighted average of individual scores
        let weights: [Double] = [0.30, 0.30, 0.20, 0.20] // Pace, Fillers, Voice Quality, Pauses
        let scores = [paceScore, fillerScore, voiceQualityScore, pauseScore]
        
        let weightedSum = zip(scores, weights).reduce(0.0) { $0 + (Double($1.0) * $1.1) }
        return Int(round(weightedSum))
    }
    
    private func generateFeedback(
        transcription: String,
        wordsPerMinute: Double,
        paceRating: String,
        fillerWordCount: Int,
        fillerWords: [String: Int],
        fillerRating: String,
        voiceQualityRating: String,
        pauseRating: String,
        longPauses: [PauseData],
        pitch: Double?,
        pitchVariability: Double?
    ) -> ([String], [String]) {
        var feedbackPoints: [String] = []
        var suggestions: [String] = []
        
        // 1. Pace feedback
        if paceRating == "Too slow" {
            feedbackPoints.append("Your speaking pace was slower than optimal at \(Int(wordsPerMinute)) words per minute.")
            suggestions.append("Try to increase your speaking pace slightly. Practice with a timer to develop a better sense of timing.")
        } else if paceRating == "Slightly slow" {
            feedbackPoints.append("Your speaking pace was slightly slower than optimal at \(Int(wordsPerMinute)) words per minute.")
            suggestions.append("Try to speak a bit more quickly, especially during straightforward parts of your content.")
        } else if paceRating == "Too fast" {
            feedbackPoints.append("Your speaking pace was faster than optimal at \(Int(wordsPerMinute)) words per minute.")
            suggestions.append("Try to slow down slightly. Taking brief pauses between thoughts can help regulate your pace.")
        } else if paceRating == "Slightly fast" {
            feedbackPoints.append("Your speaking pace was slightly faster than optimal at \(Int(wordsPerMinute)) words per minute.")
            suggestions.append("Try to slow down a bit, especially when explaining important points.")
        } else {
            feedbackPoints.append("Your speaking pace was good at \(Int(wordsPerMinute)) words per minute.")
        }
        
        // 2. Filler word feedback
        if fillerWordCount > 0 {
            let fillerList = fillerWords.map { "'\($0.key)' (\($0.value)x)" }.joined(separator: ", ")
            feedbackPoints.append("You used \(fillerWordCount) filler words: \(fillerList)")
            
            if fillerRating == "Needs improvement" || fillerRating == "Poor" {
                suggestions.append("Practice being comfortable with silence instead of using filler words. Try pausing when you would typically say a filler word.")
                suggestions.append("Record yourself in practice sessions and count your filler words to build awareness.")
            } else if fillerRating == "Average" {
                suggestions.append("You're using a moderate amount of filler words. Try to be more mindful of them, especially common ones like '\(fillerWords.keys.first ?? "um")'.")
            }
        } else {
            feedbackPoints.append("Excellent job avoiding filler words!")
        }
        
        // 3. Voice quality feedback
        if let pitch = pitch {
            let pitchDescription = pitch < 110 ? "deeper" : (pitch > 180 ? "higher" : "medium")
            feedbackPoints.append("Your voice pitch is in the \(pitchDescription) range.")
        }
        
        if voiceQualityRating == "Monotone" {
            feedbackPoints.append("Your voice could use more vocal variety to engage listeners.")
            suggestions.append("Practice adding more vocal inflection by emphasizing key words and varying your pitch more.")
        } else if voiceQualityRating == "Highly expressive" {
            feedbackPoints.append("You have excellent vocal variety which helps maintain listener engagement.")
        }
        
        // 4. Pause feedback
        if pauseRating == "Too many pauses" {
            feedbackPoints.append("Your speech contained \(longPauses.count) significant pauses, which is more than optimal.")
            suggestions.append("Work on reducing unintentional pauses by practicing your content more thoroughly.")
        } else if pauseRating == "Few pauses" {
            feedbackPoints.append("Your speech contained few significant pauses.")
            suggestions.append("Try incorporating strategic pauses after important points to let your message sink in.")
        } else {
            feedbackPoints.append("You used pauses effectively in your speech.")
        }
        
        return (feedbackPoints, suggestions)
    }
    
    // MARK: - Speech Timeline Analysis
    
    // Generate speech timeline with timestamps for visualization
    func generateSpeechTimeline(transcription: SFTranscription, audioURL: URL, voiceAnalytics: [String: Any]?) -> [SpeechTimelineSegment] {
        var timeline: [SpeechTimelineSegment] = []
        
        // Get the segments from the transcription
        for segment in transcription.segments {
            let text = segment.substring
            let isFillerWord = fillerWords.contains(text.lowercased())
            
            var pitch: Double? = nil
            var volume: Double? = nil
            
            // Extract pitch and volume if available
            // Note: In iOS 14.5+, voiceAnalytics moved to SFSpeechRecognitionMetadata
            if #available(iOS 14.5, *) {
                // Use newer APIs if needed - in POC we'll use dummy values
                // For production, we would need to access SFSpeechRecognitionMetadata
                pitch = Double.random(in: 100...140)
                volume = Double.random(in: 0.6...0.9)
            } else if #available(iOS 13, *) {
                // SFAcousticFeature doesn't have array-like properties as assumed
                // We need a different approach to extract values
                if let analytics = segment.voiceAnalytics {
                    // Basic estimation using SFAcousticFeature
                    // These would need refinement based on actual API behavior
                    pitch = 120.0 // Placeholder value
                    volume = 0.75 // Placeholder value
                }
            }
            
            let timelineSegment = SpeechTimelineSegment(
                text: text,
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration,
                isFillerWord: isFillerWord,
                pitch: pitch,
                volume: volume
            )
            
            timeline.append(timelineSegment)
        }
        
        return timeline
    }
}
