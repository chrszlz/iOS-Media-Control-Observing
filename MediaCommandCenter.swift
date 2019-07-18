//
//  MediaCommandCenter.swift
//  MediaCommandKit
//
//  Created by Chris Zelazo on 7/15/19.
//  Copyright © 2019 Chris Zelazo. All rights reserved.
//

import MediaPlayer

///
/// Supported media commands to observe.
///
public enum MediaCommand {
    case volume
    case togglePlayPause
    case play
    case pause
    case stop
    case enableLanguageOption
    case disableLanguageOption
    case changePlaybackRate
    case changeRepeatMode
    case changeShuffleMode
    case nextTrack
    case previousTrack
    case skipForward
    case skipBackward
    case seekForward
    case seekBackward
    case changePlaybackPosition
    case rating
    case like
    case dislike
    case bookmark
}

///
/// Objects who implement this protocol and register as an observer of `MediaCommandCenter`
/// will receive system command updates.
///
public protocol MediaCommandObserver: class {
    func mediaCommandCenterHandleVolumeChanged(_ volume: Double)
    func mediaCommandCenterHandleTogglePlayPause()
    func mediaCommandCenterHandlePlay()
    func mediaCommandCenterHandlePause()
    func mediaCommandCenterHandleStop()
    func mediaCommandCenterHandleEnableLanguageOption()
    func mediaCommandCenterHandleDisableLanguageOption()
    func mediaCommandCenterHandleChangePlaybackRate()
    func mediaCommandCenterHandleChangeRepeatMode()
    func mediaCommandCenterHandleChangeShuffleMode()
    func mediaCommandCenterHandleNextTrack()
    func mediaCommandCenterHandlePreviousTrack()
    func mediaCommandCenterHandleSkipForward()
    func mediaCommandCenterHandleSkipBackward()
    func mediaCommandCenterHandleSeekForward()
    func mediaCommandCenterHandleSeekBackward()
    func mediaCommandCenterHandleChangePlaybackPosition()
    func mediaCommandCenterHandleRating()
    func mediaCommandCenterHandleLike()
    func mediaCommandCenterHandleDislike()
    func mediaCommandCenterHandleBookmark()
    
    /// Calls the appropriate observer delegate command for the given MPRemoteCommand.
    /// Do not call this directly, rely on the default implementation.
    func triggerDelegateCommand(for command: MPRemoteCommand, center: MPRemoteCommandCenter)
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
    
    // MARK: - Properties
    
    /// The shared audio player used to play through the system. Set this manually to play audio,
    /// otherwise the default silent audio track will be played.
    public static var audioPlayer: AVAudioPlayer? {
        didSet {
            occupyMediaPlayer()
        }
    }
    
    public static var observedCommands = [MediaCommand]() {
        didSet {
            // Enable specified commands
            MediaCommandCenter.shared.setMediaCommands(observedCommands, enabled: true)
            
            // Disable commands that are no longer requested
            let removedCommands = oldValue.difference(from: observedCommands)
            guard !removedCommands.isEmpty else {
                return
            }
            MediaCommandCenter.shared.setMediaCommands(removedCommands, enabled: false)
        }
    }
    
    /// Map of objects observing remote commands.
    private var observations = [ObjectIdentifier: Observation]()
    
    /// Observers of `MPRemoteCommand`s. Must be retained to remove on deinit.
    private var mediaCommandTargetObservers = [(MediaCommand, Any)]()
    
    
    // MARK: - Prepare to Observe
    
    /// Call in `AppDelegate.applicationDidBecomeActive`, alternatively when a `UIView` / `UIViewController`
    /// will enter scope or has become active.
    public static func prepareToBecomeActive() {
        MediaCommandCenter.occupyMediaPlayer()
    }
    
    /// Call in `AppDelegate.applicationWillResignActive`, alternatively when a `UIView` / `UIViewController`
    /// will go out of scope or be deallocated.
    public static func prepareToResignActive() {
        MediaCommandCenter.resignMediaPlayer()
    }
    
    
    // MARK: - Add / Remove Observer
    
    /// Registers the observer object to receive updates.
    public static func addObserver(_ observer: MediaCommandObserver) {
        let id = ObjectIdentifier(observer)
        MediaCommandCenter.shared.observations[id] = Observation(observer: observer)
    }
    
    /// Stops the observer object from receiving change notifications.
    public static func removeObserver(_ observer: MediaCommandObserver) {
        let id = ObjectIdentifier(observer)
        MediaCommandCenter.shared.observations.removeValue(forKey: id)
        
        // Remove all observers and targets if no one else is observing
        if MediaCommandCenter.shared.observations.isEmpty {
            MediaCommandCenter.shared.cleanup()
        }
    }
    
    
    // MARK: - Utility
    
    /// Plays the slient audio track to take over device media playing. This should not need to be called directly.
    public static func occupyMediaPlayer() {
        // Create audio player if it does not exist
        if audioPlayer == nil {
            guard let audioTrack = MediaCommandCenter.silenceAsset else {
                fatalError("Unable to locate `silence.m4a` audio track. Ensure it is added to `Assets.xcassets` and try again. System media player events will not trigger if the audio player is not initiated.")
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
                $0.value.observer?.mediaCommandCenterHandleVolumeChanged(Double(volume))
            }
            
        default:
            break
        }
    }
    
    deinit {
        cleanup()
    }
    
    private func cleanup() {
        // Remove volume observing
        AVAudioSession.sharedInstance().removeObserver(MediaCommandCenter.shared, forKeyPath: MediaCommandCenter.volumeChangeKey)
        
        // Remove all MediaCommandCenter observers
        observations.compactMap {
            $0.value.observer
            }.forEach {
                MediaCommandCenter.removeObserver($0)
        }
        
        // Remove all MPRemoteCommandCenter observers
        mediaCommandTargetObservers.forEach { (command, observer) in
            command.remoteCommand()?.removeTarget(observer)
        }
    }
    
}

private extension MediaCommandCenter {
    
    struct Observation {
        weak var observer: MediaCommandObserver?
    }
    
    /// Private shared instance used to manage volume changes.
    private static let shared = MediaCommandCenter()
    
    /// The silent audio track used by the audio player.
    static let silenceAsset: NSDataAsset? = NSDataAsset(name: "silence")
    
    /// KVO key for system volume changes.
    static let volumeChangeKey = "outputVolume"
    
    /// Enables the given list of commands. This is needed for commands to be returned by the system - volume must be observed
    /// by KVO and media commands must be elected into with `MPRemoteCommandCenter`.
    func setMediaCommands(_ commands: [MediaCommand], enabled: Bool) {
        commands.forEach {
            setMediaCommand($0, enabled: enabled)
        }
    }
    
    /// Enables a single command. A utility for `setMediaCommands(_:enabled:)`.
    func setMediaCommand(_ command: MediaCommand, enabled: Bool) {
        switch command {
        case .volume:
            if enabled {
                AVAudioSession.sharedInstance().addObserver(self, forKeyPath: MediaCommandCenter.volumeChangeKey, options: .new, context: nil)
            } else {
                AVAudioSession.sharedInstance().removeObserver(MediaCommandCenter.shared, forKeyPath: MediaCommandCenter.volumeChangeKey)
            }
            
        default:
            guard let remoteCommand = command.remoteCommand() else {
                return
            }
            // Set enabled state for `MPRemoteCommand`
            remoteCommand.isEnabled = enabled
            
            // Add or remove observers for the given command
            if enabled {
                let observer = addCommandTarget(remoteCommand)
                mediaCommandTargetObservers.append((command, observer))
            } else {
                removeCommandTarget(command)
            }
        }
    }
    
    /// Adds the given comands as targets of their corresponding `MPRemoteCommand`.
    /// Returns the observers produced by `MPRemoteCommand.addTarget(:)`, in order to be removed as targets on deinit.
    func addCommandTargets(for commands: [MediaCommand]) -> [(MediaCommand, Any)] {
        return commands.compactMap {
            guard let remoteCommand = $0.remoteCommand() else {
                return nil
            }
            return ($0, remoteCommand)
            }.map { (command, remoteCommand) in
                return (command, addCommandTarget(remoteCommand))
        }
    }
    
    /// Adds the given comand as a target of it's corresponding `MPRemoteCommand`.
    /// Returns the observer produced by `MPRemoteCommand.addTarget(:)`, in order to be removed as a target on deinit.
    func addCommandTarget(_ command: MPRemoteCommand) -> Any {
        return command.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            self?.observations.forEach {
                $0.value.observer?.triggerDelegateCommand(for: command)
            }
            return .success
        }
    }
    
    func removeCommandTarget(_ command: MediaCommand) {
        let observer = mediaCommandTargetObservers.first { mediaCommand, _ in
            return mediaCommand == command
            }?.1
        if let observer = observer {
            command.remoteCommand()?.removeTarget(observer)
        }
    }
    
}

/// Default implementations.
public extension MediaCommandObserver {
    func mediaCommandCenterHandleVolumeChanged(_ volume: Double) { }
    func mediaCommandCenterHandleTogglePlayPause() { }
    func mediaCommandCenterHandlePlay() { }
    func mediaCommandCenterHandlePause() { }
    func mediaCommandCenterHandleStop() { }
    func mediaCommandCenterHandleEnableLanguageOption() { }
    func mediaCommandCenterHandleDisableLanguageOption() { }
    func mediaCommandCenterHandleChangePlaybackRate() { }
    func mediaCommandCenterHandleChangeRepeatMode() { }
    func mediaCommandCenterHandleChangeShuffleMode() { }
    func mediaCommandCenterHandleNextTrack() { }
    func mediaCommandCenterHandlePreviousTrack() { }
    func mediaCommandCenterHandleSkipForward() { }
    func mediaCommandCenterHandleSkipBackward() { }
    func mediaCommandCenterHandleSeekForward() { }
    func mediaCommandCenterHandleSeekBackward() { }
    func mediaCommandCenterHandleChangePlaybackPosition() { }
    func mediaCommandCenterHandleRating() { }
    func mediaCommandCenterHandleLike() { }
    func mediaCommandCenterHandleDislike() { }
    func mediaCommandCenterHandleBookmark() { }
    
    // Returns the appropriate delegate function for the given remote command.
    // This is a bit convoluted but it works.
    func triggerDelegateCommand(for command: MPRemoteCommand, center: MPRemoteCommandCenter = .shared()) {
        switch command {
        case center.togglePlayPauseCommand:
            mediaCommandCenterHandleTogglePlayPause()
        case center.playCommand:
            mediaCommandCenterHandlePlay()
        case center.pauseCommand:
            mediaCommandCenterHandlePause()
        case center.stopCommand:
            mediaCommandCenterHandleStop()
        case center.enableLanguageOptionCommand:
            mediaCommandCenterHandleEnableLanguageOption()
        case center.disableLanguageOptionCommand:
            mediaCommandCenterHandleDisableLanguageOption()
        case center.changePlaybackRateCommand:
            mediaCommandCenterHandleChangePlaybackRate()
        case center.changeRepeatModeCommand:
            mediaCommandCenterHandleChangeRepeatMode()
        case center.changeShuffleModeCommand:
            mediaCommandCenterHandleChangeShuffleMode()
        case center.nextTrackCommand:
            mediaCommandCenterHandleNextTrack()
        case center.previousTrackCommand:
            mediaCommandCenterHandlePreviousTrack()
        case center.skipForwardCommand:
            mediaCommandCenterHandleSkipForward()
        case center.skipBackwardCommand:
            mediaCommandCenterHandleSkipBackward()
        case center.seekForwardCommand:
            mediaCommandCenterHandleSeekForward()
        case center.seekBackwardCommand:
            mediaCommandCenterHandleSeekBackward()
        case center.changePlaybackPositionCommand:
            mediaCommandCenterHandleChangePlaybackPosition()
        case center.ratingCommand:
            mediaCommandCenterHandleRating()
        case center.likeCommand:
            mediaCommandCenterHandleLike()
        case center.dislikeCommand:
            mediaCommandCenterHandleDislike()
        case center.bookmarkCommand:
            mediaCommandCenterHandleBookmark()
        default:
            break
        }
    }
}

private extension MediaCommand {
    // Mapping of `MediaCommand` to `MPRemoteCommand`.
    func remoteCommand(for center: MPRemoteCommandCenter = .shared()) -> MPRemoteCommand? {
        switch self {
        case .volume:
            return nil
        case .togglePlayPause:
            return center.togglePlayPauseCommand
        case .play:
            return center.playCommand
        case .pause:
            return center.pauseCommand
        case .stop:
            return center.stopCommand
        case .enableLanguageOption:
            return center.enableLanguageOptionCommand
        case .disableLanguageOption:
            return center.disableLanguageOptionCommand
        case .changePlaybackRate:
            return center.changePlaybackRateCommand
        case .changeRepeatMode:
            return center.changeRepeatModeCommand
        case .changeShuffleMode:
            return center.changeShuffleModeCommand
        case .nextTrack:
            return center.nextTrackCommand
        case .previousTrack:
            return center.previousTrackCommand
        case .skipForward:
            return center.skipForwardCommand
        case .skipBackward:
            return center.skipBackwardCommand
        case .seekForward:
            return center.seekForwardCommand
        case .seekBackward:
            return center.seekBackwardCommand
        case .changePlaybackPosition:
            return center.changePlaybackPositionCommand
        case .rating:
            return center.ratingCommand
        case .like:
            return center.likeCommand
        case .dislike:
            return center.dislikeCommand
        case .bookmark:
            return center.bookmarkCommand
        }
    }
}

private extension Array where Element: Hashable {
    
    func difference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.subtracting(otherSet))
    }
    
}
