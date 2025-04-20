import SwiftUI

struct DetailedSpeechTimelineView: View {
    let segments: [SpeechTimelineSegment]
    @State private var selectedSegment: SpeechTimelineSegment?
    @State private var timelineScale: CGFloat = 1.0
    
    private var totalDuration: TimeInterval {
        return segments.last?.endTime ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timeline controls
            HStack {
                Text("Speech Timeline")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button(action: { zoomOut() }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    
                    Button(action: { zoomIn() }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    
                    Button(action: { resetZoom() }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
                .buttonStyle(.borderless)
            }
            
            Divider()
            
            // Timeline legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    Text("Regular speech")
                        .font(.caption)
                }
                
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange.opacity(0.4))
                        .frame(width: 12, height: 12)
                    
                    Text("Filler words")
                        .font(.caption)
                }
                
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    Text("Pause")
                        .font(.caption)
                }
            }
            .padding(.bottom, 8)
            
            // Main timeline
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Time markers and grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<6) { i in
                            HStack(spacing: 0) {
                                Text(formatTime(Double(i) * totalDuration / 5.0))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                                    .padding(.trailing, 4)
                                
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.leading, 0)
                            }
                            .frame(height: 40 * timelineScale)
                        }
                    }
                    .padding(.leading, 40)
                    
                    // Segments
                    ZStack {
                        // Place speech segments
                        ForEach(segments) { segment in
                            TimelineSegmentView(
                                segment: segment,
                                totalDuration: totalDuration,
                                scale: timelineScale,
                                isSelected: segment.id == selectedSegment?.id
                            )
                            .onTapGesture {
                                selectedSegment = segment
                            }
                        }
                    }
                    .padding(.leading, 40)
                }
                .frame(minHeight: 250)
            }
            
            // Selected segment details
            if let selected = selectedSegment {
                Divider()
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(selected.isFillerWord ? "Filler Word" : "Speech Segment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\"\(selected.text)\"")
                        .font(.headline)
                    
                    HStack {
                        Label(formatTime(selected.startTime), systemImage: "timer")
                            .font(.caption)
                        
                        Text("to")
                            .font(.caption)
                        
                        Label(formatTime(selected.endTime), systemImage: "timer")
                            .font(.caption)
                        
                        Text("(duration: \(String(format: "%.1f", selected.endTime - selected.startTime))s)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    if let pitch = selected.pitch {
                        Text("Pitch: \(String(format: "%.1f", pitch)) Hz")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: selectedSegment?.id)
            }
        }
    }
    
    // Zoom functions
    private func zoomIn() {
        timelineScale = min(timelineScale * 1.5, 5.0)
    }
    
    private func zoomOut() {
        timelineScale = max(timelineScale / 1.5, 0.5)
    }
    
    private func resetZoom() {
        timelineScale = 1.0
    }
    
    // Format time as mm:ss
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%01d:%02d", minutes, seconds)
    }
}

struct TimelineSegmentView: View {
    let segment: SpeechTimelineSegment
    let totalDuration: TimeInterval
    let scale: CGFloat
    let isSelected: Bool
    
    var body: some View {
        let yPosition = convertTimeToPosition(segment.startTime) * scale
        let height = max(24.0, convertDurationToHeight(segment.endTime - segment.startTime) * scale)
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if segment.isFillerWord {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 10))
                }
                
                Text(segment.text)
                    .font(.system(size: 11))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(
                        segment.isFillerWord ? 
                        Color.orange.opacity(0.2) : 
                        Color.blue.opacity(0.1)
                    )
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            }
        }
        .position(x: 150, y: yPosition + (height / 2))
        .animation(.spring(), value: scale)
        .animation(.spring(), value: isSelected)
    }
    
    // Convert time to vertical position
    private func convertTimeToPosition(_ time: TimeInterval) -> CGFloat {
        return CGFloat(time / totalDuration * 200.0) + 20.0
    }
    
    // Convert duration to height
    private func convertDurationToHeight(_ duration: TimeInterval) -> CGFloat {
        return CGFloat(duration / totalDuration * 50.0) + 24.0
    }
}

struct DetailedSpeechTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        DetailedSpeechTimelineView(segments: [
            SpeechTimelineSegment(
                text: "Hello",
                startTime: 0.0,
                endTime: 1.0,
                isFillerWord: false,
                pitch: 120.0,
                volume: 0.8
            ),
            SpeechTimelineSegment(
                text: "um",
                startTime: 1.2,
                endTime: 1.5,
                isFillerWord: true,
                pitch: 115.0,
                volume: 0.6
            ),
            SpeechTimelineSegment(
                text: "this is a sample",
                startTime: 1.6,
                endTime: 3.2,
                isFillerWord: false,
                pitch: 130.0,
                volume: 0.8
            )
        ])
        .padding()
        .frame(height: 400)
    }
}
