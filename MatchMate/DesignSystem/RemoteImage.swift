//
//  RemoteImage.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI
import UIKit

/// Loads a remote image through `ImageCache` (NSCache in memory + a small disk
/// cache), so scrolling is flicker-free and previously seen photos render even
/// when offline. Shows a placeholder while loading and on failure.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if didFail {
                placeholder.overlay(
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                )
            } else {
                placeholder.overlay(ProgressView())
            }
        }
        .task(id: url) { await load() }
    }

    private var placeholder: some View {
        Rectangle().fill(.quaternary)
    }

    private func load() async {
        didFail = false

        guard let url else {
            image = nil
            didFail = true
            return
        }

        // Fast path: a memory hit shows instantly with no placeholder flash.
        if let cached = ImageCache.shared.memoryImage(for: url) {
            image = cached
            return
        }

        image = nil
        do {
            let loaded = try await ImageLoader.shared.image(for: url)
            withAnimation(.easeInOut(duration: 0.2)) { image = loaded }
        } catch {
            didFail = true
        }
    }
}
