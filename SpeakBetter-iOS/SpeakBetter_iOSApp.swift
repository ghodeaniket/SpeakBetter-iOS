//
//  SpeakBetter_iOSApp.swift
//  SpeakBetter-iOS
//
//  Created by Aniket Ghode on 20/04/25.
//

import SwiftUI
import UIKit

@main
struct SpeakBetter_iOSApp: App {
    // State to track if device is supported
    @State private var isDeviceSupported = true
    
    // Initialize and perform version check
    init() {
        // Check for iOS 18.0 or higher
        // This is just an extra precaution beyond the deployment target
        if #unavailable(iOS 18.0) {
            isDeviceSupported = false
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if isDeviceSupported {
                ContentView()
            } else {
                UnsupportedVersionView()
            }
        }
    }
}

// View shown when the app is run on an unsupported iOS version
struct UnsupportedVersionView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
                .padding()
            
            Text("Unsupported iOS Version")
                .font(.title)
                .fontWeight(.bold)
            
            Text("SpeakBetter requires iOS 18 or later to function properly. Please update your device to the latest iOS version.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                if let url = URL(string: "App-Prefs:root=General&path=SOFTWARE_UPDATE_LINK") {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Check for Updates")
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
    }
}
