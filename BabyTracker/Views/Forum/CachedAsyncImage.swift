//
//  CachedAsyncImage.swift
//  BabyTracker
//
//  AsyncImage with an in-memory cache.
//
//  Exists because of a scrolling artefact: in a LazyVStack, off-screen rows
//  are destroyed and recreated, and AsyncImage restarts from its placeholder
//  every time - a frame or two of flash per image even when the bytes are
//  already local. Scrolling the feed quickly made every card flicker, which
//  reads as the whole screen trembling.
//
//  The cache is checked in init, so a hit renders the real image on the very
//  first frame - no placeholder, no flash.
//

import SwiftUI
import UIKit

/// Process-lifetime image cache. NSCache is thread-safe and evicts under
/// memory pressure on its own.
enum ImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 300
        return c
    }()

    static func image(for url: String) -> UIImage? {
        cache.object(forKey: url as NSString)
    }

    static func store(_ image: UIImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
    }
}

struct CachedAsyncImage: View {
    let url: String
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    init(url: String, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
        // Synchronous cache hit -> the image is there on the first frame.
        _image = State(initialValue: ImageCache.image(for: url))
    }

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            Rectangle()
                .fill(Warm.chipOff)
                .task(id: url) { await load() }
        }
    }

    private func load() async {
        if let hit = ImageCache.image(for: url) {
            image = hit
            return
        }
        guard let remote = URL(string: url),
              let (data, _) = try? await URLSession.shared.data(from: remote),
              let loaded = UIImage(data: data) else { return }
        ImageCache.store(loaded, for: url)
        image = loaded
    }
}
