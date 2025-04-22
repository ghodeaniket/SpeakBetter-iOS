import SwiftUI

struct AnalysisResultView: View {
    let result: SpeechAnalysisResult
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showFeedbackView = false
    @StateObject private var feedbackViewModel = FeedbackViewModel()
    
    private let tabTitles = ["Summary", "Details", "Transcript"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with score
            VStack(spacing: 8) {
                Text("Speech Analysis")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your overall speaking score")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Score circle
                ZStack {
                    Circle()
                        .stroke(
                            scoreColor.opacity(0.2),
                            lineWidth: 15
                        )
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(result.overallScore) / 100)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(
                                lineWidth: 15,
                                lineCap: .round
                            )
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(result.overallScore)")
                            .font(.system(size: 40, weight: .bold))
                        
                        Text("Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 5)
                
                // Tab picker
                Picker("View", selection: $selectedTab) {
                    ForEach(0..<tabTitles.count, id: \.self) { index in
                        Text(tabTitles[index])
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 10)
            }
            .padding(.top)
            .background(Color(.systemBackground))
            
            // Tab content
            TabView(selection: $selectedTab) {
                summaryView
                    .tag(0)
                
                detailsView
                    .tag(1)
                
                transcriptView
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Action buttons
            HStack {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Spacer()
                
                Button(action: {
                    showFeedbackView = true
                }) {
                    Label("AI Voice Feedback", systemImage: "message.and.waveform.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .background(Color(.systemBackground))
            .fullScreenCover(isPresented: $showFeedbackView) {
                FeedbackView(analysisResult: result, onDismiss: {
                    showFeedbackView = false
                })
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // MARK: - Tab Views
    
    // Summary Tab
    private var summaryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Session Summary View
                SessionSummaryView(result: result, feedbackViewModel: feedbackViewModel)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Legacy feedback display for comparison
                Text("Analysis Details")
                    .font(.headline)
                    .padding(.leading, 4)
                
                // Metrics summary
                MetricsCardView(
                    title: "Speech Metrics",
                    metrics: [
                        Metric(icon: "speedometer", name: "Pace", value: "\(Int(result.speechData.wordsPerMinute)) WPM", rating: result.paceRating),
                        Metric(icon: "textformat.abc", name: "Filler Words", value: "\(result.speechData.fillerWordCount) detected", rating: result.fillerRating),
                        Metric(icon: "waveform", name: "Voice Quality", value: voiceQualityDescription, rating: result.voiceQualityRating),
                        Metric(icon: "pause.circle", name: "Pauses", value: "\(result.speechData.longPauses.count) significant", rating: result.pauseRating)
                    ]
                )
                
                // Comparison of feedback approaches
                Button(action: {
                    showFeedbackView = true
                }) {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.accentColor)
                        
                        Text("Experience AI Voice Coaching")
                            .font(.headline)
                        
                        Text("Get personalized vocal feedback with our AI coach")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Process feedback when the view appears
            feedbackViewModel.processFeedback(from: result)
        }
    }
    
    // Details Tab
    private var detailsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Individual Scores
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Breakdown")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 15) {
                        CategoryScoreView(name: "Pace", score: result.paceScore, rating: result.paceRating, iconName: "speedometer")
                        
                        CategoryScoreView(name: "Filler Words", score: result.fillerScore, rating: result.fillerRating, iconName: "textformat.abc")
                        
                        CategoryScoreView(name: "Voice Quality", score: result.voiceQualityScore, rating: result.voiceQualityRating, iconName: "waveform")
                        
                        CategoryScoreView(name: "Pauses", score: result.pauseScore, rating: result.pauseRating, iconName: "pause.circle")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                }
                
                // Filler Words Breakdown
                if !result.speechData.fillerWords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filler Words Used")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        FillerWordsChartView(fillerWords: result.speechData.fillerWords)
                            .frame(height: 200)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                    }
                }
                
                // Voice Analytics
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice Analytics")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 20) {
                        if let pitch = result.speechData.pitch {
                            VoiceAnalyticsItemView(
                                title: "Average Pitch",
                                value: String(format: "%.1f Hz", pitch),
                                description: "Measured in Hertz, an indicator of voice frequency"
                            )
                        }
                        
                        if let pitchVariability = result.speechData.pitchVariability {
                            VoiceAnalyticsItemView(
                                title: "Pitch Variability",
                                value: String(format: "%.1f", pitchVariability),
                                description: "Higher values indicate more vocal expressiveness"
                            )
                        }
                        
                        if let jitter = result.speechData.jitter {
                            VoiceAnalyticsItemView(
                                title: "Jitter",
                                value: String(format: "%.3f%%", jitter * 100),
                                description: "Frequency variation between vocal cycles (lower is generally clearer)"
                            )
                        }
                        
                        if let shimmer = result.speechData.shimmer {
                            VoiceAnalyticsItemView(
                                title: "Shimmer",
                                value: String(format: "%.3f dB", shimmer),
                                description: "Amplitude variation between vocal cycles (moderate values are ideal)"
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                }
                
                // Pauses data
                if !result.speechData.longPauses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Significant Pauses")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(result.speechData.longPauses) { pause in
                                HStack {
                                    Text("At \(formatTime(pause.startTime))")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(String(format: "%.1f", pause.duration))s")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                                
                                if pause.id != result.speechData.longPauses.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // Transcript Tab
    private var transcriptView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Full Transcript")
                    .font(.headline)
                
                Text(result.speechData.transcription)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                
                if !result.speechData.speechTimeline.isEmpty {
                    Text("Speech Timeline")
                        .font(.headline)
                    
                    // Use the timeline view for speech visualization
                    SpeechTimelineView(segments: result.speechData.speechTimeline)
                        .frame(height: 300)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                } else {
                    Text("The timeline visualization is not available for this recording.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Methods & Properties
    
    // Color based on score
    private var scoreColor: Color {
        if result.overallScore >= 85 {
            return .green
        } else if result.overallScore >= 70 {
            return .blue
        } else if result.overallScore >= 50 {
            return .yellow
        } else {
            return .red
        }
    }
    
    // Rating color helper
    private func ratingColor(for rating: String) -> Color {
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
    
    // Formatted duration
    private var formattedDuration: String {
        let minutes = Int(result.speechData.durationInSeconds) / 60
        let seconds = Int(result.speechData.durationInSeconds) % 60
        return "\(minutes)m \(seconds)s"
    }
    
    // Format time for pause display
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Count words in transcription
    private func calculateWordCount() -> Int {
        return result.speechData.transcription.split(separator: " ").count
    }
    
    // Voice quality description
    private var voiceQualityDescription: String {
        if let pitch = result.speechData.pitch, let variability = result.speechData.pitchVariability {
            return "Pitch: \(Int(pitch)) Hz"
        } else {
            return "Not available"
        }
    }
}

// MARK: - Component Views

struct MetricsCardView: View {
    let title: String
    let metrics: [Metric]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.headline)
            
            ForEach(metrics, id: \.name) { metric in
                HStack {
                    Image(systemName: metric.icon)
                        .frame(width: 24)
                    
                    Text(metric.name)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(metric.value)
                    
                    Text(metric.rating)
                        .fontWeight(.medium)
                        .foregroundColor(ratingColor(for: metric.rating))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(ratingColor(for: metric.rating).opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.vertical, 5)
                
                if metric.name != metrics.last?.name {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func ratingColor(for rating: String) -> Color {
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

struct Metric {
    let icon: String
    let name: String
    let value: String
    let rating: String
}

struct FeedbackItemView: View {
    let iconName: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: iconName)
                .foregroundColor(color)
                .padding(.top, 2)
            
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 3)
    }
}

struct CategoryScoreView: View {
    let name: String
    let score: Int
    let rating: String
    let iconName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(scoreColor)
                
                Text(name)
                    .font(.headline)
                
                Spacer()
                
                Text(rating)
                    .font(.subheadline)
                    .foregroundColor(scoreColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 8)
                        .opacity(0.1)
                        .foregroundColor(scoreColor)
                    
                    Rectangle()
                        .frame(width: geometry.size.width * CGFloat(score) / 100, height: 8)
                        .foregroundColor(scoreColor)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
            
            HStack {
                Text("Score: \(score)/100")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
    
    private var scoreColor: Color {
        if score >= 85 {
            return .green
        } else if score >= 70 {
            return .blue
        } else if score >= 50 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct FillerWordsChartView: View {
    let fillerWords: [String: Int]
    
    // Sort and get top filler words
    private var topFillerWords: [(key: String, value: Int)] {
        let sorted = fillerWords.sorted { $0.value > $1.value }
        return Array(sorted.prefix(5))
    }
    
    // Find the maximum value for scaling
    private var maxValue: Int {
        return topFillerWords.map { $0.value }.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(topFillerWords, id: \.key) { word, count in
                HStack {
                    Text(word)
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(width: 70, alignment: .leading)
                    
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: calculateWidth(for: count, in: geometry.size.width))
                    }
                    
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
                .frame(height: 25)
            }
        }
    }
    
    private func calculateWidth(for value: Int, in totalWidth: CGFloat) -> CGFloat {
        let scaleFactor = CGFloat(value) / CGFloat(maxValue)
        return (totalWidth - 40) * scaleFactor
    }
}

struct VoiceAnalyticsItemView: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text(value)
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// Simple timeline view for visualization
struct SpeechTimelineView: View {
    let segments: [SpeechTimelineSegment]
    
    private var totalDuration: TimeInterval {
        return segments.last?.endTime ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Timeline
            ZStack(alignment: .topLeading) {
                // Time markers
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<6) { i in
                        HStack {
                            Text("\(formatTime(Double(i) * totalDuration / 5.0))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .frame(height: 50)
                    }
                }
                
                // Speech segments
                ForEach(segments) { segment in
                    timelineSegment(for: segment)
                }
            }
        }
    }
    
    private func timelineSegment(for segment: SpeechTimelineSegment) -> some View {
        let yPosition = (segment.startTime / totalDuration) * 250
        
        return HStack(spacing: 2) {
            if segment.isFillerWord {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            
            Text(segment.text)
                .font(.caption)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(segment.isFillerWord ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                .cornerRadius(4)
        }
        .position(x: 200, y: yPosition)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    let speechData = SpeechData(
        transcription: "This is a sample speech transcript that would be analyzed by the app. The app would detect filler words and calculate my speaking pace.",
        wordsPerMinute: 145.0,
        fillerWordCount: 3,
        fillerWords: ["um": 2, "like": 1],
        durationInSeconds: 75.0,
        longPauses: [
            PauseData(startTime: 10.2, duration: 2.5),
            PauseData(startTime: 45.6, duration: 3.1)
        ],
        jitter: 0.018,
        shimmer: 0.068,
        pitch: 125.0,
        pitchVariability: 12.5,
        voicingPercentage: 0.82,
        speechTimeline: [
            SpeechTimelineSegment(text: "This is", startTime: 0.0, endTime: 1.0, isFillerWord: false, pitch: 120.0, volume: 0.75),
            SpeechTimelineSegment(text: "um", startTime: 1.2, endTime: 1.5, isFillerWord: true, pitch: 115.0, volume: 0.6),
            SpeechTimelineSegment(text: "a sample speech", startTime: 1.6, endTime: 3.2, isFillerWord: false, pitch: 130.0, volume: 0.8)
        ],
        metrics: ["wpmSource": "Manual calculation"]
    )
    
    let result = SpeechAnalysisResult(
        overallScore: 85,
        paceRating: "Good",
        fillerRating: "Good",
        voiceQualityRating: "Well varied",
        pauseRating: "Good use of pauses",
        feedbackPoints: [
            "Your speaking pace was good at 145 words per minute.",
            "You used 3 filler words: 'um' (2x), 'like' (1x)",
            "Your voice pitch showed good variation that helps maintain listener engagement."
        ],
        suggestions: [
            "Try to be aware of your use of filler words and practice replacing them with brief pauses."
        ],
        speechData: speechData,
        paceScore: 95,
        fillerScore: 85,
        voiceQualityScore: 90,
        pauseScore: 80
    )
    
    return AnalysisResultView(result: result)
}
