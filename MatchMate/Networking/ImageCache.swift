//
//  ImageCache.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import UIKit
import CryptoKit

/// Two-tier image cache: an in-memory `NSCache` for instant, flicker-free reuse
/// while scrolling, plus a small on-disk cache so previously seen photos survive
/// relaunch and render while offline.
///
/// `NSCache` is thread-safe and automatically evicts under memory pressure, which
/// is exactly what we want for decoded images.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let memory = NSCache<NSURL, UIImage>()
    private let directory: URL
    private let fileManager = FileManager.default

    init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("MatchMateImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 300
        memory.totalCostLimit = 60 * 1024 * 1024 // ~60 MB of decoded images
    }

    /// Fast, thread-safe memory-only lookup (no disk I/O — safe to call on main).
    func memoryImage(for url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    /// Memory first, then disk. A disk hit is promoted back into memory.
    /// May do file I/O, so callers should invoke it off the main thread.
    func cachedImage(for url: URL) -> UIImage? {
        if let image = memory.object(forKey: url as NSURL) {
            return image
        }
        let fileURL = diskURL(for: url)
        guard let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) else {
            return nil
        }
        memory.setObject(image, forKey: url as NSURL, cost: data.count)
        return image
    }

    func store(_ image: UIImage, data: Data, for url: URL) {
        memory.setObject(image, forKey: url as NSURL, cost: data.count)
        let fileURL = diskURL(for: url)
        DispatchQueue.global(qos: .utility).async {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func diskURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }
}

/// Loads and decodes remote images, de-duplicating concurrent requests for the
/// same URL and writing results into `ImageCache`.
///
/// An `actor` so its in-flight bookkeeping is race-free; cache and network work
/// happen off the main thread.
actor ImageLoader {
    static let shared = ImageLoader()

    private var inFlight: [URL: Task<UIImage, Error>] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func image(for url: URL) async throws -> UIImage {
        // Memory or disk hit — including the offline case.
        if let cached = ImageCache.shared.cachedImage(for: url) {
            return cached
        }
        // Coalesce concurrent requests for the same URL (common while scrolling).
        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<UIImage, Error> {
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else {
                throw AppError.decodingFailed
            }
            ImageCache.shared.store(image, data: data, for: url)
            return image
        }
        inFlight[url] = task

        do {
            let image = try await task.value
            inFlight[url] = nil
            return image
        } catch {
            inFlight[url] = nil
            throw AppError.map(error)
        }
    }
}
