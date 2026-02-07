//
//  iTunesService.swift
//  music-player
//
//  iTunes Search API Client
//

import Foundation
import Combine

@MainActor
class iTunesService: ObservableObject {
    static let shared = iTunesService()

    private let baseURL = "https://itunes.apple.com"
    private let session: URLSession
    private let country = "US" // Can be changed to user's country

    @Published var searchResults: [Song] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search Songs
    func searchSongs(query: String, limit: Int = 50) async throws -> [Song] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw iTunesError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw iTunesError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw iTunesError.httpError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(iTunesSearchResponse.self, from: data)

            // Filter out songs without preview URL
            let songsWithPreview = searchResponse.results.filter { $0.previewUrl != nil }

            searchResults = songsWithPreview
            return songsWithPreview
        } catch let error as iTunesError {
            errorMessage = error.localizedDescription
            throw error
        } catch let error as DecodingError {
            errorMessage = "Failed to parse response"
            throw iTunesError.decodingError(error)
        } catch {
            errorMessage = error.localizedDescription
            throw iTunesError.networkError(error)
        }
    }

    // MARK: - Search Albums
    func searchAlbums(query: String, limit: Int = 25) async throws -> [Album] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw iTunesError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw iTunesError.invalidResponse
        }

        struct AlbumSearchResponse: Codable {
            let resultCount: Int
            let results: [Album]
        }

        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(AlbumSearchResponse.self, from: data)

        return searchResponse.results
    }

    // MARK: - Get Album Tracks
    func getAlbumTracks(albumId: Int) async throws -> [Song] {
        var components = URLComponents(string: "\(baseURL)/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(albumId)),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "country", value: country)
        ]

        guard let url = components.url else {
            throw iTunesError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw iTunesError.invalidResponse
        }

        let decoder = JSONDecoder()
        let lookupResponse = try decoder.decode(iTunesLookupResponse.self, from: data)

        // Convert lookup results to songs (skip the first result which is the album itself)
        let songs = lookupResponse.results.compactMap { $0.toSong() }

        return songs
    }

    // MARK: - Lookup Song by ID
    func getSong(id: Int) async throws -> Song {
        var components = URLComponents(string: "\(baseURL)/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(id)),
            URLQueryItem(name: "country", value: country)
        ]

        guard let url = components.url else {
            throw iTunesError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw iTunesError.invalidResponse
        }

        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(iTunesSearchResponse.self, from: data)

        guard let song = searchResponse.results.first else {
            throw iTunesError.songNotFound
        }

        return song
    }

    // MARK: - Load Curated Songs from Multiple Artists
    func loadCuratedSongs(artists: [String]) async {
        isLoading = true
        errorMessage = nil

        var allSongs: [Song] = []

        // Fetch 2-3 songs from each artist
        for artist in artists {
            do {
                var components = URLComponents(string: "\(baseURL)/search")!
                components.queryItems = [
                    URLQueryItem(name: "term", value: artist),
                    URLQueryItem(name: "country", value: country),
                    URLQueryItem(name: "media", value: "music"),
                    URLQueryItem(name: "entity", value: "song"),
                    URLQueryItem(name: "limit", value: "3")
                ]

                guard let url = components.url else { continue }

                let (data, response) = try await session.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else { continue }

                let decoder = JSONDecoder()
                let searchResponse = try decoder.decode(iTunesSearchResponse.self, from: data)

                // Filter songs with preview and add to list
                let songs = searchResponse.results.filter { $0.previewUrl != nil }
                allSongs.append(contentsOf: songs.prefix(2)) // Take max 2 per artist

            } catch {
                print("Failed to fetch songs for \(artist): \(error)")
            }
        }

        // Shuffle for variety
        searchResults = allSongs.shuffled()
        isLoading = false
    }

    // MARK: - Clear Results
    func clearResults() {
        searchResults = []
        errorMessage = nil
    }
}

// MARK: - Error Types
enum iTunesError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case networkError(Error)
    case decodingError(Error)
    case songNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .songNotFound:
            return "Song not found"
        }
    }
}
