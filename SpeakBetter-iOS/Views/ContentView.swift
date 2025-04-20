import SwiftUI
import AVFoundation
import Speech
import Combine

struct ContentView: View {
    @StateObject private var viewModel = SpeechRecognitionViewModel()
    @State private var showingAnalysisResult = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                VStack(spacing: 12) {
                    // Header with app logo - fixed spacing
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        Text("SpeakBetter AI Coach")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    
                    // Status text below header (replaces status in RealtimeAudioVisualizerView)
                    Text(viewModel.isRecording ? "Recording in progress..." : "Ready to record")
                        .font(.headline)
                        .foregroundColor(viewModel.isRecording ? .red : .secondary)
                    
                    // Enhanced audio visualization - removed internal status text
                    ZStack {
                        // Audio visualization with fixed height to prevent layout jumps
                        RealtimeAudioVisualizerView(
                            isRecording: viewModel.isRecording,
                            audioLevelData: viewModel.currentAudioData
                        )
                        .frame(height: 170)
                        .padding(.horizontal)
                    }
                    .frame(height: 170) // Fixed frame to prevent layout shifts
                    
                    // Transcription display - fixed height to prevent layout shifts
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transcription")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            Text(viewModel.transcription.isEmpty ? "Your speech will appear here in real-time as you speak..." : viewModel.transcription)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                // Disable animation to prevent layout issues
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(height: 120) // Fixed height instead of maxHeight
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .frame(height: 160) // Fixed overall height
                    
                    Spacer()
                    .frame(height: 10) // Fixed spacer height
                    
                    // Record/Stop button - consistent size and appearance
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
                    .frame(height: 80) // Fixed height
                    
                    // Button label - fixed height
                    Text(viewModel.isRecording ? "Tap to stop recording" : "Tap to start recording")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(height: 20) // Fixed height
                    
                    // Usage instructions - fixed height to prevent layout shifts
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips for best results:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        InstructionRow(number: "1", text: "Speak clearly in a quiet environment")
                        InstructionRow(number: "2", text: "Aim for 30 seconds to 3 minutes")
                        InstructionRow(number: "3", text: "Try to face your device directly")
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    .frame(height: 140) // Fixed height
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
