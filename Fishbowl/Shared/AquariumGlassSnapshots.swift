import CryptoKit
import Foundation
import UIKit

/// Widgets read finished Metal renders created by the app, rather than running a live GPU scene.
enum AquariumGlassSnapshots {
    static func url(configuration: AquariumConfiguration, format: AquariumDisplayFormat,
                    snapshot: AquariumPetSnapshot, daylight: Bool = true) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(configuration) else { return nil }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let lighting = daylight ? "day" : "evening"
        let shape = format.rawValue
        let state = snapshot.isAlive ? (snapshot.babySpecies?.rawValue ?? "normal") : "empty"
        let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BowlRepository.appGroupID)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        return root?.appendingPathComponent("MuranoSnapshots-v25", isDirectory: true)
            .appendingPathComponent("\(digest)-\(shape)-\(state)-\(lighting).png")
    }

    static func image(configuration: AquariumConfiguration, format: AquariumDisplayFormat,
                      snapshot: AquariumPetSnapshot, daylight: Bool = true) -> UIImage? {
        guard let url = url(configuration: configuration, format: format, snapshot: snapshot, daylight: daylight) else { return nil }
        if let image = UIImage(contentsOfFile: url.path) { return image }
        if snapshot.isAlive, snapshot.babySpecies != nil,
           let fallback = self.url(configuration: configuration, format: format, snapshot: .decorative(at: snapshot.date), daylight: daylight) {
            return UIImage(contentsOfFile: fallback.path)
        }
        return nil
    }
}
