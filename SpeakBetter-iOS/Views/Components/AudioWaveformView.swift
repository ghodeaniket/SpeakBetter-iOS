import SwiftUI

struct AudioWaveformView: View {
    let level: CGFloat
    let isRecording: Bool
    let barCount: Int
    let spacing: CGFloat
    let minBarHeight: CGFloat
    let maxBarHeight: CGFloat
    
    // Store the history of levels for a smoother visualization
    @State private var levelHistory: [CGFloat] = []
    
    init(
        level: CGFloat,
        isRecording: Bool,
        barCount: Int = 30,
        spacing: CGFloat = 4,
        minBarHeight: CGFloat = 3,
        maxBarHeight: CGFloat = 50
    ) {
        self.level = level
        self.isRecording = isRecording
        self.barCount = barCount
        self.spacing = spacing
        self.minBarHeight = minBarHeight
        self.maxBarHeight = maxBarHeight
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                AudioWaveformBar(
                    index: index,
                    level: getLevel(for: index),
                    isRecording: isRecording,
                    minHeight: minBarHeight,
                    maxHeight: maxBarHeight
                )
            }
        }
        .animation(.easeInOut(duration: 0.1), value: level)
        .onChange(of: level) { newLevel in
            updateLevelHistory(with: newLevel)
        }
        .onAppear {
            // Initialize history with zeros
            levelHistory = Array(repeating: 0, count: barCount)
        }
    }
    
    // Update the level history with the new value
    private func updateLevelHistory(with newLevel: CGFloat) {
        if isRecording {
            // Shift history left and add new value at the end
            if levelHistory.count >= barCount {
                levelHistory.removeFirst()
            }
            levelHistory.append(newLevel)
        } else {
            // Reset to zeros if not recording
            levelHistory = Array(repeating: 0, count: barCount)
        }
    }
    
    // Get level value for a specific bar
    private func getLevel(for index: Int) -> CGFloat {
        guard isRecording else { return 0.1 }
        
        // If we have history data, use it
        if index < levelHistory.count {
            return levelHistory[index]
        }
        
        // Fallback: use current level with some randomness
        return level * CGFloat.random(in: 0.7...1.3)
    }
}

struct AudioWaveformBar: View {
    let index: Int
    let level: CGFloat
    let isRecording: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat
    
    // Generate a height based on level
    private var height: CGFloat {
        guard isRecording && level > 0 else { return minHeight }
        
        // Create a sine wave pattern for some bars to create more visual interest
        let sineValue = sin(Double(index) * 0.5) * 0.3 + 0.7
        
        // Combine with actual audio level
        let calculatedHeight = level * maxHeight * CGFloat(sineValue)
        
        // Ensure minimum height
        return max(minHeight, calculatedHeight)
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(width: 4, height: height)
            .animation(.spring(dampingFraction: 0.6, blendDuration: 0.1), value: height)
    }
    
    // Dynamic color based on recording state and level
    private var barColor: Color {
        if !isRecording {
            return Color.gray.opacity(0.5)
        }
        
        // Higher levels are more saturated
        let normalizedLevel = min(1.0, level * 1.5)
        
        return Color.blue.opacity(0.4 + (normalizedLevel * 0.6))
    }
}

// A more reactive audio visualization for recording
struct RealtimeAudioVisualizerView: View {
    let isRecording: Bool
    let audioLevelData: AudioLevelData?
    
    @State private var animationCounter = 0
    
    var body: some View {
        VStack(spacing: 4) {
            // Removed status text to avoid duplication

            ZStack {
                // Background circles - made consistent size
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.blue.opacity(isRecording ? 0.2 : 0.1), lineWidth: 2)
                        .frame(width: CGFloat(60 + (i * 30)), height: CGFloat(60 + (i * 30)))
                }
                
                // Main visualization
                ZStack {
                    // Center microphone icon
                    Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(isRecording ? .red : .blue)
                    
                    // Animated pulse when recording
                    if isRecording {
                        Circle()
                            .stroke(Color.red, lineWidth: 2)
                            .frame(width: 60, height: 60)
                            .scaleEffect(pulsatingScale)
                            .opacity(pulsatingOpacity)
                        
                        ForEach(0..<8) { i in
                            RecordingLevelBar(
                                angle: .degrees(Double(i) * 45),
                                level: getBarLevel(at: i),
                                isActive: isRecording
                            )
                        }
                    }
                }
            }
            .frame(height: 120) // Reduced height to prevent layout shifts
            
            // Audio level meter if recording - simplified and made more visible
            if isRecording, let audioData = audioLevelData {
                VStack(spacing: 2) {
                    // Audio level meter - more prominent design
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                                .frame(height: 8)
                            
                            // Level indicator
                            Rectangle()
                                .fill(levelColor(for: audioData.normalizedValue))
                                .frame(width: geometry.size.width * CGFloat(audioData.normalizedValue), height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                    
                    // Labels - simplified
                    HStack {
                        Text("Low")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Only show this when actively speaking
                        if audioData.isSpeaking && audioData.normalizedValue > 0.2 {
                            Text("Speaking")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        Text("High")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .onAppear {
            // Start animation when view appears
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: true)) {
                animationCounter = 1
            }
        }
    }
    
    // Pulsating animation properties
    private var pulsatingScale: CGFloat {
        1.0 + (0.2 * CGFloat(animationCounter))
    }
    
    private var pulsatingOpacity: Double {
        0.8 - (0.6 * Double(animationCounter))
    }
    
    // Get level for a specific bar
    private func getBarLevel(at index: Int) -> CGFloat {
        guard let audioData = audioLevelData else { return 0.2 }
        
        // Get the base level from the audio data
        let baseLevel = CGFloat(audioData.normalizedValue)
        
        // Add some variance based on the bar position
        let variance = CGFloat.random(in: 0.8...1.2)
        
        return baseLevel * variance
    }
    
    // Dynamic color based on level
    private func levelColor(for level: Float) -> Color {
        if level < 0.3 {
            return .blue
        } else if level < 0.7 {
            return .green
        } else {
            return .red
        }
    }
}

// Individual level bar in the circular visualization
struct RecordingLevelBar: View {
    let angle: Angle
    let level: CGFloat
    let isActive: Bool
    
    var body: some View {
        let barLength = 10.0 + (level * 40.0)
        
        return Rectangle()
            .fill(isActive ? Color.red.opacity(0.6) : Color.gray.opacity(0.3))
            .frame(width: 4, height: barLength)
            .cornerRadius(2)
            .offset(y: -40 - (barLength / 2))
            .rotationEffect(angle)
            .animation(.spring(dampingFraction: 0.6), value: level)
            .animation(.spring(dampingFraction: 0.6), value: isActive)
    }
}

// Preview
struct AudioWaveformView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            AudioWaveformView(level: 0.7, isRecording: true)
                .frame(height: 100)
                .padding()
                .previewDisplayName("Standard Waveform")
            
            RealtimeAudioVisualizerView(
                isRecording: true,
                audioLevelData: AudioLevelData(
                    averagePower: -20.0,
                    peakPower: -10.0,
                    normalizedValue: 0.7,
                    isSpeaking: true,
                    levelHistory: []
                )
            )
            .padding()
            .previewDisplayName("Circular Visualizer")
            
            RealtimeAudioVisualizerView(
                isRecording: false,
                audioLevelData: nil
            )
            .padding()
            .previewDisplayName("Inactive Visualizer")
        }
    }
}
