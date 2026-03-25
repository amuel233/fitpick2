//
//  CachedImageView.swift
//  fitpick2
//
//  Created by Bryan Gavino on 2/13/26.
//

import SwiftUI
import Kingfisher

struct CachedImageView: View {
    let urlString: String
    var contentMode: SwiftUI.ContentMode = .fill
    
    var body: some View {
        KFImage(URL(string: urlString))
            .placeholder {
                // While loading or if offline & missing
                ZStack {
                    Color.gray.opacity(0.1)
                    ProgressView()
                }
            }
            // MEMORY CACHE: Fast scrolling
            .cacheMemoryOnly()
            // DISK CACHE: Offline support (Keep for 7 days)
            .diskCacheExpiration(.days(7))
            // TRANSITION: Smooth fade-in
            .fade(duration: 0.25)
            // RETRY: If network fails, try again automatically
            .retry(maxCount: 3, interval: .seconds(2))
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }
}
