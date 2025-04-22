# SpeakBetter AI Coach iOS - POC Implementation

This repository contains the Proof of Concept (POC) implementation for the SpeakBetter AI Coach iOS application. The POC aims to validate the feasibility of an AI-powered speech coaching app with real-time feedback capabilities.

## Project Structure

The project follows the MVVM (Model-View-ViewModel) architecture pattern:

```
SpeakBetter-iOS/
├── Models/                 # Data models
│   └── SpeechData.swift    # Core speech analysis data structures
├── Views/                  # SwiftUI views
│   ├── Components/         # Reusable UI components
│   │   ├── AudioWaveformView.swift    # Audio visualization
│   │   ├── FeedbackCardView.swift     # Interactive feedback cards
│   │   ├── SessionSummaryView.swift   # Session overview component
│   │   └── SpeechTimelineView.swift   # Speech visualization
│   ├── AnalysisResultView.swift       # Speech analysis results
│   ├── ContentView.swift              # Main recording interface
│   └── FeedbackView.swift             # AI voice coaching interface
├── ViewModels/             # View logic and state
│   ├── FeedbackViewModel.swift        # Feedback presentation logic
│   └── SpeechRecognitionViewModel.swift # Recording and analysis logic
├── Services/               # Core services
│   ├── AudioRecordingService.swift    # Audio capture functionality
│   ├── FeedbackService.swift          # AI feedback generation and TTS
│   ├── SpeechAnalysisService.swift    # Speech metrics analysis
│   ├── SpeechRecognitionService.swift # Transcription service
│   └── VoiceAnalyticsService.swift    # Voice quality analysis
├── Utilities/              # Helper functions and utilities
├── SpeakBetter_iOSApp.swift # Main application entry point
├── Info.plist              # App configuration and permissions
└── README.md               # This file
```

## Implementation Progress

### Phase 1: Core Speech Recognition
- Project initialization with SwiftUI
- MVVM architecture setup
- Framework integrations (AVFoundation, Speech Framework)
- Permission handling for microphone access
- Real-time speech transcription
- Basic speech analysis (pace, filler words)

### Phase 2: Speech Analysis
- SFVoiceAnalytics integration
- Enhanced speech analysis metrics
- Detection of filler words and pauses
- Voice quality analysis (pitch, variability)
- Visualization for speech metrics
- Detailed performance breakdown

### Phase 3: Feedback Generation (Current)
- AI-powered feedback system
- Text-to-speech vocal coaching
- Personalized feedback based on performance
- Interactive feedback interface
- Category-based feedback organization
- Session summary and overview
- Visual analysis of speech patterns

## Features Implemented

- **Speech Recording and Analysis**
  - Real-time transcription with timestamp precision
  - Analysis of speaking pace, filler words, and pauses
  - Voice quality assessment (pitch, jitter, shimmer)
  - Performance scoring and rating

- **AI Coaching Interface**
  - Voice-based feedback using natural TTS
  - Structured coaching feedback
  - Personalized suggestions based on performance
  - Interactive feedback exploration

- **User Interface**
  - Clean, intuitive recording interface
  - Detailed analysis results
  - Interactive feedback cards
  - Session summary dashboard
  - Speech timeline visualization

## Requirements

- Xcode 15.0 or later
- iOS 18.0 SDK or later
- Swift 5.9 or later
- iPhone with iOS 18.0 or later (for testing)

## Next Steps

After validation of Phase 3, Phase 4 will focus on:

1. Performance testing and optimization
2. Battery impact assessment and optimization
3. Accuracy validation against expert evaluations
4. User experience enhancements
5. Preparation for App Store submission

## Important Notes

- This is a Proof of Concept implementation
- The app requires iOS 18.0 or later due to framework dependencies
- The app requires microphone and speech recognition permissions
- For best results, use in a quiet environment with clear speech
