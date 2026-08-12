import AVFoundation
import Foundation
import UIKit

struct RestTimerAlertConfiguration: Equatable {
    var soundEnabled: Bool
    var hapticEnabled: Bool
}

@MainActor
final class RestTimerAlertService {
    static let shared = RestTimerAlertService()

    private var alertPlayer: AVAudioPlayer?
    private var restoreTask: Task<Void, Never>?

    func play(
        configuration: RestTimerAlertConfiguration,
        audioPlayer: AudioPlayerService
    ) {
        restoreTask?.cancel()
        audioPlayer.endTemporaryAlertDuck()

        if configuration.hapticEnabled {
            let notification = UINotificationFeedbackGenerator()
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            notification.prepare()
            impact.prepare()
            notification.notificationOccurred(.warning)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else { return }
                impact.impactOccurred(intensity: 1)
            }
        }

        guard configuration.soundEnabled else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true)
            let player = try AVAudioPlayer(data: Self.twoToneAlertData())
            player.volume = 1
            player.prepareToPlay()
            alertPlayer = player
            audioPlayer.beginTemporaryAlertDuck()
            player.play()

            restoreTask = Task { @MainActor [weak self, weak audioPlayer] in
                try? await Task.sleep(for: .milliseconds(1_250))
                guard !Task.isCancelled else { return }
                audioPlayer?.endTemporaryAlertDuck()
                self?.alertPlayer = nil
            }
        } catch {
            audioPlayer.endTemporaryAlertDuck()
            alertPlayer = nil
        }
    }

    static func twoToneAlertData(sampleRate: Int = 44_100) -> Data {
        let segments: [(frequency: Double?, duration: Double)] = [
            (880, 0.16),
            (nil, 0.07),
            (1_320, 0.20),
            (nil, 0.12),
            (880, 0.16),
            (nil, 0.07),
            (1_320, 0.22)
        ]
        var samples: [Int16] = []

        for segment in segments {
            let sampleCount = max(1, Int(Double(sampleRate) * segment.duration))
            for index in 0..<sampleCount {
                guard let frequency = segment.frequency else {
                    samples.append(0)
                    continue
                }
                let phase = 2 * Double.pi * frequency * Double(index) / Double(sampleRate)
                let edgeSamples = max(1, min(sampleCount / 2, sampleRate / 200))
                let attack = min(1, Double(index) / Double(edgeSamples))
                let release = min(1, Double(sampleCount - index - 1) / Double(edgeSamples))
                let envelope = max(0, min(attack, release))
                let value = sin(phase) * envelope * 0.82 * Double(Int16.max)
                samples.append(Int16(value.rounded()))
            }
        }

        let bytesPerSample = MemoryLayout<Int16>.size
        let dataSize = samples.count * bytesPerSample
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize), to: &data)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(1), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * bytesPerSample), to: &data)
        append(UInt16(bytesPerSample), to: &data)
        append(UInt16(16), to: &data)
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(dataSize), to: &data)
        for sample in samples {
            append(UInt16(bitPattern: sample), to: &data)
        }
        return data
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
