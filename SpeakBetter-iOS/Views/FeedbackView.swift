import SwiftUI

struct FeedbackView: View {
    @StateObject private var viewModel = FeedbackViewModel()
    @State private var selectedCategory: FeedbackCategory?
    @State private var showingCategorySelector = false
    
    let analysisResult: SpeechAnalysisResult
    let onDismiss: () -> Void
    
    private let columnSpacing: CGFloat = 12
    private let gridItems = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                // Header
                feedbackHeader
                
                // Scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        // Score and overview
                        scoreOverview
                        
                        // Main feedback content
                        if selectedCategory != nil {
                            categoryDetailView
                        } else {
                            feedbackGrid
                        }
                    }
                    .padding()
                }
                
                // Bottom action bar
                bottomActionBar
            }
        }
        .onAppear {
            // Process feedback when the view appears
            viewModel.processFeedback(from: analysisResult)
            
            // Auto-start vocal feedback after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.deliverVocalFeedback()
            }
        }
        .onDisappear {
            // Stop speaking when view disappears
            viewModel.stopSpeaking()
        }
    }
    
    // MARK: - View Components
    
    // Header
    private var feedbackHeader: some View {
        VStack(spacing: 0) {
            HStack {
                if selectedCategory == nil {
                    Text("Speech Feedback")
                        .font(.title2)
                        .fontWeight(.bold)
                } else {
                    Button(action: {
                        withAnimation {
                            selectedCategory = nil
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("All Feedback")
                        }
                        .foregroundColor(.accentColor)
                    }
                    
                    Spacer()
                    
                    Text(selectedCategory?.rawValue ?? "")
                        .font(.headline)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            Divider()
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // Score overview
    private var scoreOverview: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                // Score circle
                ZStack {
                    Circle()
                        .stroke(
                            scoreColor.opacity(0.2),
                            lineWidth: 8
                        )
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(analysisResult.overallScore) / 100)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(
                                lineWidth: 8,
                                lineCap: .round
                            )
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(analysisResult.overallScore)")
                            .font(.system(size: 30, weight: .bold))
                        
                        Text("Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Speech stats
                VStack(alignment: .trailing, spacing: 6) {
                    Label(formattedDuration, systemImage: "clock")
                        .font(.subheadline)
                    
                    Label("\(Int(analysisResult.speechData.wordsPerMinute)) words per minute", systemImage: "speedometer")
                        .font(.subheadline)
                    
                    Label("\(calculateWordCount()) words", systemImage: "text.word.spacing")
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
            }
            
            // Vocal feedback controls
            vocalFeedbackControls
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
    
    // Vocal feedback controls
    private var vocalFeedbackControls: some View {
        HStack {
            if viewModel.isSpeakingFeedback {
                Button(action: {
                    viewModel.pauseSpeaking()
                }) {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            } else {
                Button(action: {
                    viewModel.deliverVocalFeedback()
                }) {
                    Label(
                        viewModel.feedbackReadingCompleted ? "Replay Feedback" : "Listen to Feedback", 
                        systemImage: "play.fill"
                    )
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            
            Spacer()
            
            if viewModel.isSpeakingFeedback {
                // Animated speaker icon
                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 6 + CGFloat(i) * 4)
                            .cornerRadius(1.5)
                            .opacity(0.7)
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }
    
    // Feedback grid
    private var feedbackGrid: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Key Observations")
                .font(.headline)
                .padding(.leading, 4)
            
            LazyVGrid(columns: gridItems, spacing: columnSpacing) {
                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                    if viewModel.hasFeedbackForCategory(category) {
                        Button(action: {
                            withAnimation {
                                selectedCategory = category
                            }
                        }) {
                            categoryCardView(category)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            if !viewModel.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Top Suggestion")
                        .font(.headline)
                        .padding(.leading, 4)
                        .padding(.top, 4)
                    
                    if let topSuggestion = viewModel.suggestions.first {
                        FeedbackCardView(
                            feedback: topSuggestion,
                            isHighlighted: viewModel.currentlyHighlightedFeedback?.id == topSuggestion.id,
                            onTap: {
                                viewModel.speakFeedbackPoint(topSuggestion)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // Category card view
    private func categoryCardView(_ category: FeedbackCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(viewModel.colorForCategory(category))
                
                Text(category.rawValue)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            let feedbackCount = viewModel.getFeedbackForCategory(category).count
            let suggestionCount = viewModel.getSuggestionsForCategory(category).count
            let totalCount = feedbackCount + suggestionCount
            
            Text("\(totalCount) point\(totalCount != 1 ? "s" : "")")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Rating label
            switch category {
            case .pace:
                ratingLabel(analysisResult.paceRating, color: viewModel.colorForCategory(category))
            case .fillerWords:
                ratingLabel(analysisResult.fillerRating, color: viewModel.colorForCategory(category))
            case .voiceQuality:
                ratingLabel(analysisResult.voiceQualityRating, color: viewModel.colorForCategory(category))
            case .pauses:
                ratingLabel(analysisResult.pauseRating, color: viewModel.colorForCategory(category))
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(height: 150)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // Rating label
    private func ratingLabel(_ rating: String, color: Color) -> some View {
        Text(rating)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
    
    // Category detail view
    private var categoryDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let category = selectedCategory {
                // Category name and score
                HStack {
                    Text(category.rawValue)
                        .font(.headline)
                    
                    Spacer()
                    
                    // Rating based on category
                    switch category {
                    case .pace:
                        ratingLabel(analysisResult.paceRating, color: viewModel.colorForCategory(category))
                    case .fillerWords:
                        ratingLabel(analysisResult.fillerRating, color: viewModel.colorForCategory(category))
                    case .voiceQuality:
                        ratingLabel(analysisResult.voiceQualityRating, color: viewModel.colorForCategory(category))
                    case .pauses:
                        ratingLabel(analysisResult.pauseRating, color: viewModel.colorForCategory(category))
                    }
                }
                .padding(.leading, 4)
                
                // Display feedback points
                if !viewModel.getFeedbackForCategory(category).isEmpty {
                    Text("Observations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        .padding(.top, 4)
                    
                    ForEach(viewModel.getFeedbackForCategory(category)) { point in
                        FeedbackCardView(
                            feedback: point,
                            isHighlighted: viewModel.currentlyHighlightedFeedback?.id == point.id,
                            onTap: {
                                viewModel.speakFeedbackPoint(point)
                            }
                        )
                    }
                }
                
                // Display suggestions
                if !viewModel.getSuggestionsForCategory(category).isEmpty {
                    Text("Suggestions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        .padding(.top, 4)
                    
                    ForEach(viewModel.getSuggestionsForCategory(category)) { suggestion in
                        FeedbackCardView(
                            feedback: suggestion,
                            isHighlighted: viewModel.currentlyHighlightedFeedback?.id == suggestion.id,
                            onTap: {
                                viewModel.speakFeedbackPoint(suggestion)
                            }
                        )
                    }
                }
                
                // Additional metrics based on category
                categorySpecificMetrics(category)
            }
        }
    }
    
    // Category-specific metrics
    @ViewBuilder
    private func categorySpecificMetrics(_ category: FeedbackCategory) -> some View {
        switch category {
        case .pace:
            paceMetricsView
                .padding(.top, 8)
        case .fillerWords:
            fillerWordsMetricsView
                .padding(.top, 8)
        case .voiceQuality:
            voiceQualityMetricsView
                .padding(.top, 8)
        case .pauses:
            pausesMetricsView
                .padding(.top, 8)
        }
    }
    
    // Pace metrics
    private var paceMetricsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pace Metrics")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Words Per Minute")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(analysisResult.speechData.wordsPerMinute))")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Target Range")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("120-160 WPM")
                            .font(.headline)
                    }
                }
                
                // Pace gauge
                paceGauge
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
    
    // Pace gauge visualization
    private var paceGauge: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .frame(width: geometry.size.width, height: 8)
                        .foregroundColor(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    
                    // Ideal range indicator
                    Rectangle()
                        .frame(
                            width: geometry.size.width * 0.4,
                            height: 8
                        )
                        .position(
                            x: geometry.size.width * 0.5,
                            y: 4
                        )
                        .foregroundColor(Color.green.opacity(0.3))
                        .cornerRadius(4)
                    
                    // Current pace indicator
                    let pacePosition = min(1.0, max(0.0, Double(analysisResult.speechData.wordsPerMinute) / 200.0))
                    
                    Circle()
                        .frame(width: 16, height: 16)
                        .foregroundColor(viewModel.colorForCategory(.pace))
                        .position(
                            x: CGFloat(pacePosition) * geometry.size.width,
                            y: 4
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
            }
            .frame(height: 16)
            
            // Labels
            HStack {
                Text("Slow (<100)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Ideal (120-160)")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("Fast (>180)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // Filler words metrics
    private var fillerWordsMetricsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filler Word Usage")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            VStack(alignment: .leading, spacing: 16) {
                // Total count
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Filler Words")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(analysisResult.speechData.fillerWordCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Filler Word Rate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if calculateWordCount() > 0 {
                            Text("\(Int((Double(analysisResult.speechData.fillerWordCount) / Double(calculateWordCount())) * 100))%")
                                .font(.headline)
                        } else {
                            Text("0%")
                                .font(.headline)
                        }
                    }
                }
                
                // Filler word breakdown
                if !analysisResult.speechData.fillerWords.isEmpty {
                    Text("Most Common Fillers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    FillerWordsChartView(fillerWords: analysisResult.speechData.fillerWords)
                        .frame(height: 150)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
    
    // Voice quality metrics
    private var voiceQualityMetricsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Metrics")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 20) {
                if let pitch = analysisResult.speechData.pitch {
                    VoiceAnalyticsItemView(
                        title: "Average Pitch",
                        value: String(format: "%.1f Hz", pitch),
                        description: "Measured in Hertz, an indicator of voice frequency"
                    )
                }
                
                if let pitchVariability = analysisResult.speechData.pitchVariability {
                    VoiceAnalyticsItemView(
                        title: "Pitch Variability",
                        value: String(format: "%.1f", pitchVariability),
                        description: "Higher values indicate more vocal expressiveness"
                    )
                }
                
                if let jitter = analysisResult.speechData.jitter {
                    VoiceAnalyticsItemView(
                        title: "Jitter",
                        value: String(format: "%.3f%%", jitter * 100),
                        description: "Frequency variation between vocal cycles (lower is generally clearer)"
                    )
                }
                
                if let shimmer = analysisResult.speechData.shimmer {
                    VoiceAnalyticsItemView(
                        title: "Shimmer",
                        value: String(format: "%.3f dB", shimmer),
                        description: "Amplitude variation between vocal cycles (moderate values are ideal)"
                    )
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
    
    // Pauses metrics
    private var pausesMetricsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pause Analysis")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            VStack(alignment: .leading, spacing: 16) {
                // Summary
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Significant Pauses")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(analysisResult.speechData.longPauses.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Pause Time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        let totalPauseTime = analysisResult.speechData.longPauses.reduce(0.0) { $0 + $1.duration }
                        Text("\(String(format: "%.1f", totalPauseTime))s")
                            .font(.headline)
                    }
                }
                
                // Pause details
                if !analysisResult.speechData.longPauses.isEmpty {
                    Text("Pause Details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(analysisResult.speechData.longPauses) { pause in
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
                            
                            if pause.id != analysisResult.speechData.longPauses.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
    
    // Bottom action bar
    private var bottomActionBar: some View {
        HStack {
            Button(action: onDismiss) {
                Text("Close")
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            Spacer()
            
            if selectedCategory == nil {
                // Practice again button
                Button(action: onDismiss) {
                    Label("Practice Again", systemImage: "arrow.clockwise")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .background(
            Color(UIColor.systemBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 6, y: -3)
        )
    }
    
    // MARK: - Helper Methods & Properties
    
    // Color based on score
    private var scoreColor: Color {
        if analysisResult.overallScore >= 85 {
            return .green
        } else if analysisResult.overallScore >= 70 {
            return .blue
        } else if analysisResult.overallScore >= 50 {
            return .yellow
        } else {
            return .red
        }
    }
    
    // Formatted duration
    private var formattedDuration: String {
        let minutes = Int(analysisResult.speechData.durationInSeconds) / 60
        let seconds = Int(analysisResult.speechData.durationInSeconds) % 60
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
        return analysisResult.speechData.transcription.split(separator: " ").count
    }
}

// MARK: - Previews

struct FeedbackView_Previews: PreviewProvider {
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
        
        return FeedbackView(analysisResult: result, onDismiss: {})
    }
}
