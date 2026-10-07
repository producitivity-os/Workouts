import AVKit
import SwiftUI

#if canImport(AppKit)
import AppKit

private struct AnimatedGIFView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.animates = true
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        view.image = NSImage(data: data)
        view.animates = true
    }
}
#elseif canImport(UIKit)
import UIKit

private struct AnimatedGIFView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.image = UIImage(data: data)
    }
}
#endif

struct ExerciseMediaView: View {
    let data: Data
    let mimeType: String
    @State private var videoURL: URL?

    var body: some View {
        Group {
            if mimeType.hasPrefix("video/"), let videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
            } else {
                AnimatedGIFView(data: data)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: data) {
            guard mimeType.hasPrefix("video/") else { return }
            let suffix = mimeType.contains("quicktime") ? "mov" : "mp4"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("workout-preview-\(data.hashValue)")
                .appendingPathExtension(suffix)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? data.write(to: url, options: .atomic)
            }
            videoURL = url
        }
    }
}
