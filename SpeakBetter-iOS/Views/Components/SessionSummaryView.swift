import SwiftUI

struct SessionSummaryView: View {
    let result: SpeechAnalysisResult
    @ObservedObject var feedbackViewModel: FeedbackViewModel
    @State private var showFullFeedback = false
    @State private var topFeedbackPoints: [FeedbackPoint] = []
    @State private var topSuggestion: FeedbackPoint?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with score
            HStack {
                Text("Session Summary")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Score circle
                ZStack {
                    Circle()
                        .stroke(
                            scoreColor.opacity(0.2),
                            lineWidth: 8
                        )
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(result.overallScore) / 100)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(
                                lineWidth: 8,
                                lineCap: .round
                            )
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(result.overallScore)")
                            .font(.system(size: 20, weight: .bold))
                        
                        Text("Score")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Key metrics
            metricsGridView
            
            // Key observations
            VStack(alignment: .leading, spacing: 12) {
                Text("Key Observations")
                    .font(.headline)
                
                if topFeedbackPoints.isEmpty {
                    Text("Processing feedback...")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .padding()
                } else {
                    ForEach(topFeedbackPoints) { point in
                        HStack(alignment: .top) {
                            Image(systemName: point.category.icon)
                                .foregroundColor(feedbackViewModel.colorForCategory(point.category))
                                .frame(width: 24, height: 24)
                            
                            Text(point.text)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Top suggestion
            if let suggestion = topSuggestion {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggestion")
                        .font(.headline)
                    
                    HStack(alignment: .top) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 24, height: 24)
                        
                        Text(suggestion.text)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            // Action buttons
            HStack {
                Button(action: {
                    feedbackViewModel.deliverVocalFeedback()
                }) {
                    Label("Listen", systemImage: "play.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Spacer()
                
                Button(action: {
                    showFullFeedback = true
                }) {
                    Text("View Full Feedback")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .onAppear {
            // Update our local state for the view
            self.topFeedbackPoints = feedbackViewModel.getTopFeedback(count: 2)
            self.topSuggestion = feedbackViewModel.suggestions.first
        }
        .fullScreenCover(isPresented: $showFullFeedback) {
            FeedbackView(analysisResult: result, onDismiss: {
                showFullFeedback = false
            })
        }
    }
    
    // Metrics grid view
    private var metricsGridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]) {
            metricItem(
                value: "\(Int(result.speechData.wordsPerMinute))",
                label: "WPM",
                icon: "speedometer",
                color: colorForRating(result.paceRating)
            )
            
            metricItem(
                value: "\(result.speechData.fillerWordCount)",
                label: "Fillers",
                icon: "textformat.abc",
                color: colorForRating(result.fillerRating)
            )
            
            metricItem(
                value: formattedDuration,
                label: "Duration",
                icon: "clock",
                color: .blue
            )
            
            metricItem(
                value: "\(calculateWordCount())",
                label: "Words",
                icon: "text.word.spacing",
                color: .blue
            )
        }
    }
    
    // Individual metric item
    private func metricItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
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
    
    // Formatted duration
    private var formattedDuration: String {
        let minutes = Int(result.speechData.durationInSeconds) / 60
        let seconds = Int(result.speechData.durationInSeconds) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    // Count words in transcription
    private func calculateWordCount() -> Int {
        return result.speechData.transcription.split(separator: " ").count
    }
}

// MARK: - Previews

struct SessionSummaryView_Previews: PreviewProvider {
    static var previews: some View {
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
            speechTimeline: []
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
        
        let viewModel = FeedbackViewModel()
        viewModel.processFeedback(from: result)
        
        return SessionSummaryView(result: result, feedbackViewModel: viewModel)
            .padding()
            .background(Color(UIColor.systemBackground))
            .previewLayout(.sizeThatFits)
    }
}
