import SwiftUI

struct AnalysisResultView: View {
    let result: SpeechAnalysisResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with score
                HStack {
                    VStack(alignment: .leading) {
                        Text("Speech Analysis")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Here's how you did")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Score circle
                    ZStack {
                        Circle()
                            .stroke(
                                scoreColor.opacity(0.2),
                                lineWidth: 10
                            )
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(result.overallScore) / 100)
                            .stroke(
                                scoreColor,
                                style: StrokeStyle(
                                    lineWidth: 10,
                                    lineCap: .round
                                )
                            )
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(result.overallScore)")
                            .font(.system(size: 30, weight: .bold))
                    }
                    .frame(width: 80, height: 80)
                }
                .padding(.bottom, 10)
                
                // Metrics summary
                VStack(alignment: .leading, spacing: 10) {
                    Text("Speech Metrics")
                        .font(.headline)
                    
                    // Pace
                    HStack {
                        Image(systemName: "speedometer")
                        Text("Pace: ")
                            .fontWeight(.medium)
                        Text("\(Int(result.speechData.wordsPerMinute)) words per minute")
                        Spacer()
                        Text(result.paceRating)
                            .foregroundColor(ratingColor(for: result.paceRating))
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 5)
                    
                    // Filler words
                    HStack {
                        Image(systemName: "textformat.abc")
                        Text("Filler Words: ")
                            .fontWeight(.medium)
                        Text("\(result.speechData.fillerWordCount) detected")
                        Spacer()
                        Text(result.fillerRating)
                            .foregroundColor(ratingColor(for: result.fillerRating))
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 5)
                    
                    // Duration
                    HStack {
                        Image(systemName: "clock")
                        Text("Duration: ")
                            .fontWeight(.medium)
                        Text(formattedDuration)
                    }
                    .padding(.vertical, 5)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Transcription
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Speech")
                        .font(.headline)
                    
                    Text(result.speechData.transcription)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray5))
                        .cornerRadius(5)
                }
                
                // Feedback
                VStack(alignment: .leading, spacing: 10) {
                    Text("Feedback")
                        .font(.headline)
                    
                    ForEach(result.feedbackPoints, id: \.self) { point in
                        HStack(alignment: .top) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.blue)
                                .padding(.top, 2)
                            
                            Text(point)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 3)
                    }
                }
                
                // Suggestions
                if !result.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Suggestions for Improvement")
                            .font(.headline)
                        
                        ForEach(result.suggestions, id: \.self) { suggestion in
                            HStack(alignment: .top) {
                                Image(systemName: "lightbulb")
                                    .foregroundColor(.yellow)
                                    .padding(.top, 2)
                                
                                Text(suggestion)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                
                // Button
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
            }
            .padding()
        }
    }
    
    // Color based on score
    private var scoreColor: Color {
        if result.overallScore >= 80 {
            return .green
        } else if result.overallScore >= 60 {
            return .yellow
        } else {
            return .red
        }
    }
    
    // Rating color helper
    private func ratingColor(for rating: String) -> Color {
        switch rating {
        case "Excellent", "Good":
            return .green
        case "Too slow", "Too fast":
            return .yellow
        case "Needs improvement":
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
}

#Preview {
    let speechData = SpeechData(
        transcription: "This is a sample speech transcript that would be analyzed by the app. The app would detect filler words and calculate my speaking pace.",
        wordsPerMinute: 145.0,
        fillerWordCount: 3,
        fillerWords: ["um": 2, "like": 1],
        durationInSeconds: 75.0
    )
    
    let result = SpeechAnalysisResult(
        overallScore: 85,
        paceRating: "Good",
        fillerRating: "Good",
        feedbackPoints: [
            "Your speaking pace was good at 145 words per minute.",
            "You used 3 filler words: 'um' (2x), 'like' (1x)"
        ],
        suggestions: [
            "Try to be aware of your use of filler words and practice replacing them with brief pauses."
        ],
        speechData: speechData
    )
    
    return AnalysisResultView(result: result)
}
