import AppKit
import SwiftUI

@main
struct RenderAppIcon {
    @MainActor
    static func main() throws {
        let outputPath: String
        if CommandLine.arguments.count > 1 {
            outputPath = CommandLine.arguments[1]
        } else {
            outputPath = "/Users/nate/Desktop/fishbowl/Fishbowl/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
        }

        let size = CGSize(width: 1024, height: 1024)
        let artwork = AquariumAppIconArtwork()
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: artwork)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1

        guard let cgImage = renderer.cgImage else {
            throw RenderError.failedToCreateImage
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.failedToEncodePNG
        }

        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try pngData.write(to: outputURL, options: .atomic)

        print("Wrote app icon to \(outputURL.path)")
    }
}

private enum RenderError: LocalizedError {
    case failedToCreateImage
    case failedToEncodePNG

    var errorDescription: String? {
        switch self {
        case .failedToCreateImage:
            return "Could not render the app icon artwork."
        case .failedToEncodePNG:
            return "Could not encode the rendered icon as PNG."
        }
    }
}
