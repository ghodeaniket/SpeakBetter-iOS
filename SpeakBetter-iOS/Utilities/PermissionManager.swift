import Foundation
import AVFoundation
import Speech

class PermissionManager {
    
    enum PermissionType {
        case microphone
        case speech
    }
    
    enum PermissionStatus {
        case granted
        case denied
        case undetermined
        case notDetermined
    }
    
    static func checkMicrophonePermission(completion: @escaping (PermissionStatus) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(.granted)
        case .denied:
            completion(.denied)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted ? .granted : .denied)
                }
            }
        @unknown default:
            completion(.notDetermined)
        }
    }
    
    static func checkSpeechRecognitionPermission(completion: @escaping (PermissionStatus) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion(.granted)
                case .denied:
                    completion(.denied)
                case .restricted:
                    completion(.denied)
                case .notDetermined:
                    completion(.undetermined)
                @unknown default:
                    completion(.notDetermined)
                }
            }
        }
    }
    
    static func checkAllPermissions(completion: @escaping ([PermissionType: PermissionStatus]) -> Void) {
        var results = [PermissionType: PermissionStatus]()
        let group = DispatchGroup()
        
        group.enter()
        checkMicrophonePermission { status in
            results[.microphone] = status
            group.leave()
        }
        
        group.enter()
        checkSpeechRecognitionPermission { status in
            results[.speech] = status
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
}
