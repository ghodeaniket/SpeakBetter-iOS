import SwiftUI

struct VoiceMetricsView: View {
    let speechData: SpeechData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice Metrics")
                .font(.headline)
            
            // Voice quality metrics
            VStack(spacing: 24) {
                // Pitch metrics
                if let pitchValue = speechData.pitch, let pitchVariability = speechData.pitchVariability {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Pitch")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(Int(pitchValue)) Hz")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        VoiceMetricGaugeView(
                            value: normalizePitch(pitchValue),
                            minLabel: "Low",
                            maxLabel: "High",
                            colors: [.blue, .purple, .red]
                        )
                        
                        Text("Pitch variability: \(String(format: "%.1f", pitchVariability))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(pitchVariabilityDescription(pitchVariability))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(.bottom, 4)
                    
                    Divider()
                }
                
                // Voice stability (jitter/shimmer)
                if let jitter = speechData.jitter, let shimmer = speechData.shimmer {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Voice Stability")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text(voiceStabilityRating(jitter: jitter, shimmer: shimmer))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Jitter")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VoiceMetricGaugeView(
                                    value: normalizeJitter(jitter),
                                    minLabel: "Stable",
                                    maxLabel: "Variable",
                                    colors: [.green, .yellow, .orange]
                                )
                                
                                Text(String(format: "%.2f%%", jitter * 100))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Shimmer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VoiceMetricGaugeView(
                                    value: normalizeShimmer(shimmer),
                                    minLabel: "Stable",
                                    maxLabel: "Variable",
                                    colors: [.green, .yellow, .orange]
                                )
                                
                                Text(String(format: "%.2f dB", shimmer))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(voiceStabilityDescription(jitter: jitter, shimmer: shimmer))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Explanation
            VStack(alignment: .leading, spacing: 8) {
                Text("What do these metrics mean?")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Pitch: The highness or lowness of your voice, measured in Hertz (Hz).")
                        Text("• Pitch Variability: How much your voice pitch changes during speech. Higher values indicate more expressive speech.")
                        Text("• Jitter: Small variations in the frequency of your voice from cycle to cycle. Low-to-moderate values are normal.")
                        Text("• Shimmer: Variations in the amplitude of your voice. Related to voice quality and breath control.")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                } label: {
                    Text("Tap to learn more")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Helper Methods
    
    // Normalize pitch to 0.0-1.0 range
    // Typical human pitch: 80Hz (deep male) to 250Hz (high female)
    private func normalizePitch(_ pitch: Double) -> Double {
        let minPitch = 80.0
        let maxPitch = 250.0
        return min(1.0, max(0.0, (pitch - minPitch) / (maxPitch - minPitch)))
    }
    
    // Normalize jitter (typical values are 0.5% to 1.0% for normal voice)
    private func normalizeJitter(_ jitter: Double) -> Double {
        // Convert from decimal to percentage first
        let jitterPercent = jitter * 100
        // Scale where 0% is 0.0 and 3% or higher is 1.0
        return min(1.0, max(0.0, jitterPercent / 3.0))
    }
    
    // Normalize shimmer (typical values are 0.04 to 0.21 dB)
    private func normalizeShimmer(_ shimmer: Double) -> Double {
        // Scale where 0.0 dB is 0.0 and 0.6 dB or higher is 1.0
        return min(1.0, max(0.0, shimmer / 0.6))
    }
    
    // Generate description based on pitch variability
    private func pitchVariabilityDescription(_ variability: Double) -> String {
        if variability < 5 {
            return "Your voice shows little pitch variation, which can sound monotonous."
        } else if variability < 15 {
            return "Your voice has a moderate amount of pitch variation."
        } else if variability < 25 {
            return "Your voice shows good pitch variation, which helps engage listeners."
        } else {
            return "Your voice is highly expressive with significant pitch variation."
        }
    }
    
    // Generate a rating based on jitter and shimmer
    private func voiceStabilityRating(jitter: Double, shimmer: Double) -> String {
        let jitterPercent = jitter * 100
        
        if jitterPercent < 0.5 && shimmer < 0.2 {
            return "Excellent"
        } else if jitterPercent < 1.0 && shimmer < 0.4 {
            return "Good"
        } else if jitterPercent < 1.5 && shimmer < 0.5 {
            return "Average"
        } else {
            return "Variable"
        }
    }
    
    // Generate description based on jitter and shimmer
    private func voiceStabilityDescription(jitter: Double, shimmer: Double) -> String {
        let jitterPercent = jitter * 100
        
        if jitterPercent < 0.5 && shimmer < 0.2 {
            return "Your voice shows excellent stability and control."
        } else if jitterPercent < 1.0 && shimmer < 0.4 {
            return "Your voice shows good stability with normal variation."
        } else if jitterPercent < 1.5 && shimmer < 0.5 {
            return "Your voice has average stability with some natural variation."
        } else {
            return "Your voice shows more variation than average, which can affect clarity."
        }
    }
}

struct VoiceMetricGaugeView: View {
    let value: Double // 0.0 to 1.0
    let minLabel: String
    let maxLabel: String
    let colors: [Color]
    
    var body: some View {
        VStack(spacing: 4) {
            // Gauge
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    // Value indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: colors),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(value), height: 6)
                    
                    // Marker
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        .position(x: geometry.size.width * CGFloat(value), y: 3)
                }
            }
            .frame(height: 12)
            
            // Labels
            HStack {
                Text(minLabel)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(maxLabel)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Preview
struct VoiceMetricsView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceMetricsView(speechData: SpeechData(
            transcription: "Sample transcription",
            wordsPerMinute: 150.0,
            fillerWordCount: 5,
            fillerWords: ["um": 3, "like": 2],
            durationInSeconds: 60.0,
            longPauses: [],
            jitter: 0.012,
            shimmer: 0.25,
            pitch: 142.0,
            pitchVariability: 18.5,
            voicingPercentage: 0.78,
            speechTimeline: [],
            metrics: ["wpmSource": "Manual calculation"]
        ))
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
