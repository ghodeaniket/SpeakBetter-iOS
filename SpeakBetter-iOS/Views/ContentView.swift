import SwiftUI
import AVFoundation
import Speech
import Combine

struct ContentView: View {
    @StateObject private var viewModel = SpeechRecognitionViewModel()
    @State private var showingAnalysisResult = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var durationTimer: Timer?
    
    // Format the recording duration as MM:SS
    private var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                VStack(spacing: 16) {
                    // Header with app logo
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        Text("SpeakBetter AI Coach")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .padding(.top)
                    
                    // Enhanced audio visualization
                    RealtimeAudioVisualizerView(
                        isRecording: viewModel.isRecording,
                        audioLevelData: viewModel.currentAudioData
                    )
                    .frame(height: 180)
                    .padding(.horizontal)
                    
                    // Recording status
                    HStack {
                        if viewModel.isRecording {
                            // Recording animation
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .modifier(PulseEffect())
                            
                            Text("Recording in progress...")
                                .font(.headline)
                        } else if viewModel.isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 4)
                            
                            Text("Analyzing speech...")
                                .font(.headline)
                        } else {
                            Image(systemName: "mic.slash")
                                .foregroundColor(.gray)
                                .padding(.trailing, 4)
                            
                            Text("Ready to record")
                                .font(.headline)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    
                    // Enhanced transcription display with more space
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Transcription")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // Add word count when there's content
                            if !viewModel.transcription.isEmpty {
                                Text("\(viewModel.transcription.split(separator: " ").count) words")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        
                        ScrollView {
                            Text(viewModel.transcription.isEmpty ? "Your speech will appear here in real-time as you speak..." : viewModel.transcription)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .animation(.default, value: viewModel.transcription)
                                .foregroundColor(viewModel.transcription.isEmpty ? .secondary : .primary)
                        }
                        .frame(minHeight: 200, maxHeight: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Improved record/stop button with better visual cues
                    VStack(spacing: 10) {
                        // Add recording duration if recording
                        if viewModel.isRecording {
                            Text(formattedDuration)
                                .font(.system(.title3, design: .monospaced))
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            if viewModel.isRecording {
                                viewModel.stopRecording()
                            } else {
                                viewModel.startRecording()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.isRecording ? Color.red : Color.blue)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                                
                                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(viewModel.isAnalyzing)
                        .opacity(viewModel.isAnalyzing ? 0.7 : 1.0)
                        
                        // Button label
                        Text(viewModel.isRecording ? "Tap to stop recording" : "Tap to start recording")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                    
                    // Remove bottom instructions and add a small spacer instead
                    Spacer(minLength: 20)
                }
                
                // Overlay for analyzing state
                if viewModel.isAnalyzing {
                    VStack {
                        Spacer()
                        
                        // Results processing indicator
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Analyzing your speech...")
                                .font(.headline)
                            
                            Text("This will just take a moment")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                    .background(Color.black.opacity(0.2))
                    .ignoresSafeArea()
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .alert(isPresented: $viewModel.showPermissionAlert) {
                Alert(
                    title: Text("Microphone Access Required"),
                    message: Text("SpeakBetter needs access to your microphone to record and analyze your speech. Please grant permission in Settings."),
                    primaryButton: .default(Text("Open Settings"), action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }),
                    secondaryButton: .cancel()
                )
            }
            .onChange(of: viewModel.analysisResult != nil) { hasResult in
                if hasResult {
                    showingAnalysisResult = true
                }
            }
            .sheet(isPresented: $showingAnalysisResult) {
                if let result = viewModel.analysisResult {
                    AnalysisResultView(result: result)
                }
            }
        }
        .onAppear {
            viewModel.checkPermission()
        }
        .onChange(of: viewModel.isRecording) { isRecording in
            if isRecording {
                // Start the timer and reset duration
                recordingDuration = 0
                durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    recordingDuration += 1
                }
            } else {
                // Stop the timer
                durationTimer?.invalidate()
                durationTimer = nil
            }
        }
    }
}

// Animation and visual components are now in separate files

// Pulse animation for recording indicator
struct PulseEffect: ViewModifier {
    @State private var pulsate = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsate ? 1.2 : 1.0)
            .opacity(pulsate ? 0.7 : 1.0)
            .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsate)
            .onAppear {
                pulsate = true
            }
    }
}

// Instruction row component
struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(number)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20, alignment: .center)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    ContentView()
}
