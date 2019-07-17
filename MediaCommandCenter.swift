//
//  MediaCommandCenter.swift
//  MediaCommandKit
//
//  Created by Chris Zelazo on 7/15/19.
//  Copyright © 2019 Chris Zelazo. All rights reserved.
//

import MediaPlayer

///
/// Objects who implement this protocol and register as an observer of `MediaCommandCenter`
/// will receive system command updates.
///
public protocol MediaCommandObserver: class {
    
    func mediaCommandDidTogglePlayPause()
    
    func mediaCommandDidUpdateVolume(_ volume: Double)
    
}

///
/// RemoteCommandKit is a set of utilites that provides the ability to listen for system media controls
/// such as Play/Pause () and Volume (`AVAudioSession`) changes.
///
/// In order to receive Play/Pause commands, an `AVAudioPlayer` instance is initiated with a silent, 00:00 length
/// audio track ensuring that controls are routed to the app as opposed to the system or other media providers. Then
/// a callback is attacted to the `MPRemoteCommandCenter` event.
///
/// Note: `MPRemoteCommandCenter` events will not trigger if the silent audio track is not initiated.
///
/// Volume changes are tracked through`AVAudioSession` key-value observation.
///
open class MediaCommandCenter: NSObject {
    
    /// Map of objects observing remote commands.
    private var observations = [ObjectIdentifier : Observation]()
    
    /// The shared audio player used to play through the system.
    private static var audioPlayer: AVAudioPlayer?
    
    public override init() {
        super.init()
        
        // Observe volume changes
        AVAudioSession.sharedInstance().addObserver(self, forKeyPath: MediaCommandCenter.volumeChangeKey, options: .new, context: nil)
        
        // Observe play / pause toggle
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            
            // Update all observers for toggle
            self?.observations.forEach {
                $0.value.observer?.mediaCommandDidTogglePlayPause()
            }
            return .success
        }
    }
    
    /// Call in `AppDelegate.applicationDidBecomeActive`, alternatively when a `UIView` / `UIViewController`
    /// will enter scope or has become active.
    public static func prepareToBecomeActive() {
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled = true
        MediaCommandCenter.occupyMediaPlayer()
    }
    
    /// Call in `AppDelegate.applicationWillResignActive`, alternatively when a `UIView` / `UIViewController`
    /// will go out of scope or be deallocated.
    public static func prepareToResignActive() {
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled = false
        MediaCommandCenter.resignMediaPlayer()
    }
    
    /// Plays the slient audio track to take over device media playing. This should not need to be called directly.
    public static func occupyMediaPlayer() {
        // Create audio player if it does not exist
        if audioPlayer == nil {
            guard let audioTrack = MediaCommandCenter.silenceAsset else {
                fatalError("Unable to locate `silence.m4a` audio track. Ensure it is added to `Assets.xcassets` and try again.")
            }
            
            audioPlayer = try? AVAudioPlayer(data: audioTrack.data)
        }
        
        // Play
        audioPlayer?.play()
    }
    
    /// Stops the silent audio track from playing, resigning control of the system media player. This should not
    /// need to be called directly.
    public static func resignMediaPlayer() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    /// KVO observation of system volume changes. Be wary of overriding.
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let key = keyPath else { return }
        switch key {
        case MediaCommandCenter.volumeChangeKey:
            guard let dict = change, let volume = dict[.newKey] as? Float, volume != 0.5 else {
                return
            }
            // Update all observers for volume change
            observations.forEach {
                $0.value.observer?.mediaCommandDidUpdateVolume(Double(volume))
            }
            
        default:
            break
        }
    }
    
    deinit {
        // Remove volume observing
        AVAudioSession.sharedInstance().removeObserver(MediaCommandCenter.shared, forKeyPath: MediaCommandCenter.volumeChangeKey)
        
        // Remove all observers
        observations.compactMap {
            $0.value.observer
            }.forEach {
                MediaCommandCenter.removeObserver($0)
        }
    }
    
}

public extension MediaCommandCenter {
    
    /// Registers the observer object to receive updates.
    static func addObserver(_ observer: MediaCommandObserver) {
        let id = ObjectIdentifier(observer)
        MediaCommandCenter.shared.observations[id] = Observation(observer: observer)
    }
    
    /// Stops the observer object from receiving change notifications.
    static func removeObserver(_ observer: MediaCommandObserver) {
        let id = ObjectIdentifier(observer)
        MediaCommandCenter.shared.observations.removeValue(forKey: id)
    }
    
}

private extension MediaCommandCenter {
    
    struct Observation {
        weak var observer: MediaCommandObserver?
    }
    
    /// Private shared instance used to manage volume changes.
    private static let shared = MediaCommandCenter()
    
    /// The silent audio track used by the audio player.
    private static let silenceAsset: NSDataAsset? = NSDataAsset(name: "silence")
    
    /// KVO key for system volume changes.
    private static let volumeChangeKey = "outputVolume"
    
}

/// Default implementations.
public extension MediaCommandObserver {
    
    func mediaCommandDidTogglePlayPause() { }
    
    func mediaCommandDidUpdateVolume(_ volume: Double) { }
    
}

