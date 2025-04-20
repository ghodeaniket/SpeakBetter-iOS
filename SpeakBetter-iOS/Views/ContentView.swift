import SwiftUI
import AVFoundation
import Speech

struct ContentView: View {
    @StateObject private var viewModel = SpeechRecognitionViewModel()
    @State private var showingAnalysisResult = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                Text("SpeakBetter AI Coach")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Spacer()
                
                // Recording status indicator
                HStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.gray)
                        .frame(width: 20, height: 20)
                    
                    Text(viewModel.isRecording ? "Recording in progress..." : "Ready to record")
                        .font(.headline)
                }
                
                // Transcription display
                ScrollView {
                    Text(viewModel.transcription.isEmpty ? "Your speech will appear here..." : viewModel.transcription)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Record button
                Button(action: {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                        showingAnalysisResult = viewModel.analysisResult != nil
                    } else {
                        viewModel.startRecording()
                    }
                }) {
                    HStack {
                        Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 24))
                        
                        Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                            .font(.headline)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(viewModel.isRecording ? Color.red : Color.blue)
                    .cornerRadius(10)
                }
                
                // Usage instructions
                VStack(alignment: .leading, spacing: 10) {
                    Text("How to use:")
                        .font(.headline)
                    
                    HStack(alignment: .top) {
                        Text("1.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Tap the Start Recording button and speak clearly")
                            .font(.subheadline)
                    }
                    
                    HStack(alignment: .top) {
                        Text("2.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Speak for 30 seconds to 3 minutes")
                            .font(.subheadline)
                    }
                    
                    HStack(alignment: .top) {
                        Text("3.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Tap Stop Recording to get instant feedback")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
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

#Preview {
    ContentView()
}
