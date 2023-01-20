import Foundation
import UIKit
import AVFoundation
import MapboxNavigationNative

final class EventsMetadataProvider: EventsMetadataInterface {
    private let appMetadata: AppMetadata?
    private let screen: UIScreen
    private let audioSession: AVAudioSession
    private let device: UIDevice

    //init(appMetadata: AppMetadata? = nil,
    init(sessionState: SessionState = .init(),
         screen: UIScreen = .main,
         audioSession: AVAudioSession = .sharedInstance(),
         device: UIDevice = UIDevice.current) {
        self.appMetadata = AppMetadata(name: "1Tap test",
                                       version: "0.5.0(1000)",
                                       userId: "6RKlY3VyZYechMr2Y25WOTNt0dl1",
                                       sessionId: UUID().uuidString) // appMetadata
        self.screen = screen
        self.audioSession = audioSession
        self.device = device
    }

    var applicationState: UIApplication.State {
        if Thread.isMainThread {
            return UIApplication.shared.applicationState
        } else {
            return DispatchQueue.main.sync { UIApplication.shared.applicationState }
        }
    }

    // Expects to run on main thread
    private var screenBrightness: Int { Int(screen.brightness * 100) }

    private var volumeLevel: Int { Int(audioSession.outputVolume * 100) }
    private var audioType: AudioType { audioSession.telemetryAudioType }
    private var batteryPluggedIn: Bool { [.charging, .full].contains(device.batteryState) }
    private var batteryLevel: Int { device.batteryLevel >= 0 ? Int(device.batteryLevel * 100) : -1 }
    private var connectivity: String { return "" } // TODO(kried)
    private var percentTimeInPortrait: Int = 0
    private var percentTimeInForeground: Int = 0

    private var totalTimeInForeground: TimeInterval = 0
    private var totalTimeInBackground: TimeInterval = 0

    func provideEventsMetadata() -> EventsMetadata {
        return .init(volumeLevel: volumeLevel as NSNumber,
                     audioType: audioType.rawValue as NSNumber,
                     screenBrightness: screenBrightness as NSNumber,
                     percentTimeInForeground: percentTimeInForeground as NSNumber,
                     percentTimeInPortrait: percentTimeInPortrait as NSNumber,
                     batteryPluggedIn: batteryPluggedIn as NSNumber,
                     batteryLevel: batteryLevel as NSNumber,
                     connectivity: connectivity,
                     appMetadata: appMetadata)
    }

    private func updateTimeState(session: SessionState) {
        var totalTimeInPortrait = session.timeSpentInPortrait
        var totalTimeInLandscape = session.timeSpentInLandscape
        if UIDevice.current.orientation.isPortrait {
            totalTimeInPortrait += abs(session.lastTimeInPortrait.timeIntervalSinceNow)
        } else if UIDevice.current.orientation.isLandscape {
            totalTimeInLandscape += abs(session.lastTimeInLandscape.timeIntervalSinceNow)
        }
        percentTimeInPortrait = totalTimeInPortrait + totalTimeInLandscape == 0 ? 100 : Int((totalTimeInPortrait / (totalTimeInPortrait + totalTimeInLandscape)) * 100)

        totalTimeInForeground = session.timeSpentInForeground
        totalTimeInBackground = session.timeSpentInBackground
        if applicationState == .active {
            totalTimeInForeground += abs(session.lastTimeInForeground.timeIntervalSinceNow)
        } else {
            totalTimeInBackground += abs(session.lastTimeInBackground.timeIntervalSinceNow)
        }
        percentTimeInForeground = totalTimeInPortrait + totalTimeInLandscape == 0 ? 100 : Int((totalTimeInPortrait / (totalTimeInPortrait + totalTimeInLandscape) * 100))
    }
}

extension AVAudioSession {
    var telemetryAudioType: AudioType {
        if currentRoute.outputs.contains(where: { [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains($0.portType) }) {
            return .bluetooth
        }
        if currentRoute.outputs.contains(where: { [.headphones, .airPlay, .HDMI, .lineOut, .carAudio, .usbAudio].contains($0.portType) }) {
            return .headphones
        }
        if currentRoute.outputs.contains(where: { [.builtInSpeaker, .builtInReceiver].contains($0.portType) }) {
            return .speaker
        }
        return .unknown
    }
}
