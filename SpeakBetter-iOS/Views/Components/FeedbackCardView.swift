import SwiftUI

struct FeedbackCardView: View {
    let feedback: FeedbackPoint
    let isHighlighted: Bool
    var onTap: () -> Void
    
    // Animation states
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack {
                Image(systemName: feedback.category.icon)
                    .foregroundColor(isHighlighted ? .white : .accentColor)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(feedback.category.rawValue)
                    .font(.headline)
                    .foregroundColor(isHighlighted ? .white : .primary)
                
                Spacer()
                
                // Audio indicator when highlighted
                if isHighlighted {
                    AudioWaveIndicator()
                } else {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
            }
            
            // Divider
            Rectangle()
                .fill(isHighlighted ? Color.white.opacity(0.2) : Color.secondary.opacity(0.2))
                .frame(height: 1)
            
            // Feedback text
            Text(feedback.text)
                .font(.body)
                .foregroundColor(isHighlighted ? .white : .primary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Suggestion tag for suggestions
            if feedback.isSuggestion {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                    
                    Text("Suggestion")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(isHighlighted ? .white.opacity(0.9) : .yellow)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHighlighted ? Color.white.opacity(0.2) : Color.yellow.opacity(0.1))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isHighlighted ? Color.accentColor : Color(UIColor.secondarySystemBackground))
        )
        .shadow(color: isHighlighted ? Color.accentColor.opacity(0.4) : Color.black.opacity(0.05), 
                radius: isHighlighted ? 8 : 2, 
                x: 0, 
                y: isHighlighted ? 4 : 1)
        .scaleEffect(scale)
        .opacity(opacity)
        .animation(.spring(response: 0.3), value: isHighlighted)
        .onTapGesture {
            withAnimation(.spring(response: 0.2)) {
                scale = 0.95
                opacity = 0.9
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2)) {
                    scale = 1.0
                    opacity = 1.0
                }
                onTap()
            }
        }
        .onAppear {
            // Initial animation
            scale = 0.95
            opacity = 0.8
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// Audio waveform visualization for when feedback is playing
struct AudioWaveIndicator: View {
    @State private var phase: CGFloat = 0
    
    let bars = 4
    let barWidth: CGFloat = 2
    let spacing: CGFloat = 3
    let minHeight: CGFloat = 3
    let maxHeight: CGFloat = 12
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<bars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: barWidth, height: height(for: index))
            }
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
    }
    
    private func height(for index: Int) -> CGFloat {
        let sineValue = sin(phase + CGFloat(index) * 0.5)
        return minHeight + (maxHeight - minHeight) * (sineValue + 1) / 2
    }
}

// Provides visual preview in SwiftUI Canvas
struct FeedbackCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            FeedbackCardView(
                feedback: FeedbackPoint(
                    category: .pace,
                    text: "Your speaking pace was good at 145 words per minute.",
                    priority: 3
                ),
                isHighlighted: true,
                onTap: {}
            )
            
            FeedbackCardView(
                feedback: FeedbackPoint(
                    category: .fillerWords,
                    text: "You used 12 filler words: 'um' (7x), 'like' (3x), 'you know' (2x)",
                    priority: 5
                ),
                isHighlighted: false,
                onTap: {}
            )
            
            FeedbackCardView(
                feedback: FeedbackPoint(
                    category: .voiceQuality,
                    text: "Try adding more vocal inflection by emphasizing key words and varying your pitch more.",
                    priority: 4,
                    isSuggestion: true
                ),
                isHighlighted: false,
                onTap: {}
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
