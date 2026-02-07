//
//  Song.swift
//  music-player
//
//  iTunes API Data Models
//

import Foundation

// MARK: - iTunes Search Response
struct iTunesSearchResponse: Codable {
    let resultCount: Int
    let results: [Song]
}

// MARK: - Song Model (iTunes Track)
struct Song: Codable, Identifiable, Equatable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let collectionName: String?
    let artworkUrl100: String?
    let previewUrl: String?
    let trackTimeMillis: Int?
    let releaseDate: String?
    let primaryGenreName: String?
    let trackPrice: Double?
    let currency: String?

    // Identifiable conformance
    var id: Int { trackId }

    // Computed properties for UI
    var name: String { trackName }

    var albumName: String {
        collectionName ?? "Unknown Album"
    }

    var thumbnailURL: URL? {
        // Get higher resolution artwork (replace 100x100 with 500x500)
        guard let urlString = artworkUrl100 else { return nil }
        let highRes = urlString.replacingOccurrences(of: "100x100", with: "500x500")
        return URL(string: highRes)
    }

    var smallThumbnailURL: URL? {
        guard let urlString = artworkUrl100 else { return nil }
        return URL(string: urlString)
    }

    var streamURL: URL? {
        guard let urlString = previewUrl else { return nil }
        return URL(string: urlString)
    }

    var durationSeconds: Double {
        guard let millis = trackTimeMillis else { return 30 } // Default 30s for preview
        return Double(millis) / 1000.0
    }

    var durationFormatted: String {
        let seconds = Int(durationSeconds)
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.trackId == rhs.trackId
    }
}

// MARK: - Album Model (iTunes Collection)
struct Album: Codable, Identifiable {
    let collectionId: Int
    let collectionName: String
    let artistName: String
    let artworkUrl100: String?
    let trackCount: Int?
    let releaseDate: String?
    let primaryGenreName: String?

    var id: Int { collectionId }

    var name: String { collectionName }

    var thumbnailURL: URL? {
        guard let urlString = artworkUrl100 else { return nil }
        let highRes = urlString.replacingOccurrences(of: "100x100", with: "500x500")
        return URL(string: highRes)
    }
}

// MARK: - iTunes Album Lookup Response
struct iTunesLookupResponse: Codable {
    let resultCount: Int
    let results: [iTunesLookupResult]
}

// Wrapper for mixed results (collection + tracks)
struct iTunesLookupResult: Codable {
    let wrapperType: String?
    let collectionType: String?
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let collectionName: String?
    let artworkUrl100: String?
    let previewUrl: String?
    let trackTimeMillis: Int?

    var isSong: Bool {
        wrapperType == "track"
    }

    func toSong() -> Song? {
        guard isSong, let trackId = trackId, let trackName = trackName else {
            return nil
        }
        return Song(
            trackId: trackId,
            trackName: trackName,
            artistName: artistName ?? "Unknown Artist",
            collectionName: collectionName,
            artworkUrl100: artworkUrl100,
            previewUrl: previewUrl,
            trackTimeMillis: trackTimeMillis,
            releaseDate: nil,
            primaryGenreName: nil,
            trackPrice: nil,
            currency: nil
        )
    }
}
