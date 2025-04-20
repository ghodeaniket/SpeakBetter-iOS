# SpeakBetter AI Coach iOS - POC Implementation

This repository contains the Proof of Concept (POC) implementation for the SpeakBetter AI Coach iOS application. The POC aims to validate the integration of speech recognition capabilities for speech coaching features.

## Project Structure

The project follows the MVVM (Model-View-ViewModel) architecture pattern:

```
SpeakBetter-iOS/
├── Models/                 # Data models
├── Views/                  # SwiftUI views
├── ViewModels/             # View logic and state
├── Services/               # Core services (speech recognition, analysis)
├── Utilities/              # Helper functions and utilities
├── SpeakBetter_iOSApp.swift # Main application entry point
├── Info.plist              # App configuration and permissions
└── README.md               # This file
```

## Phase 1 Implementation

Phase 1 focuses on:

1. Project initialization with SwiftUI
2. MVVM architecture setup
3. Framework integrations:
   - AVFoundation for audio recording
   - Speech Framework for speech recognition
   - Placeholder for SFVoiceAnalytics integration
4. Permission handling for microphone access

## Features Implemented

- Basic UI for recording speech
- Real-time speech transcription
- Permission handling for microphone and speech recognition
- Foundation for speech analysis (pace, filler words)
- Results display with simple feedback

## Requirements

- Xcode 15.0 or later
- iOS 18.0 SDK or later
- Swift 5.9 or later
- iPhone with iOS 18.0 or later (for testing)

## Next Steps

After validation of Phase 1, Phase 2 will focus on:

1. Implementing the SFVoiceAnalytics integration
2. Enhancing speech analysis capabilities
3. Improving the feedback generation algorithm
4. Adding visualization for speech metrics

## Important Notes

- This is a Proof of Concept implementation
- SFVoiceAnalytics implementation is planned for Phase 2
- The app requires iOS 18.0 or later due to framework dependencies
- The app requires microphone and speech recognition permissions
