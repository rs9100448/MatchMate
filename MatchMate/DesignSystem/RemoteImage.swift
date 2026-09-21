//
//  RemoteImage.swift
//  MatchMate
//
//  Created by Ravindra on 21/09/26.
//

import SwiftUI

/// Thin wrapper over `AsyncImage` with a consistent placeholder and failure
/// state. `AsyncImage` also gives us URL-based caching for free.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
            switch phase {
            case .empty:
                placeholder
                    .overlay(ProgressView())
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder
                    .overlay(
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                    )
            @unknown default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Rectangle().fill(.quaternary)
    }
}
