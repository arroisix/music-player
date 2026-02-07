import SwiftUI
import AppKit

struct MusicPlayerView: View {
    @StateObject private var iTunes = iTunesService.shared
    @StateObject private var player = AudioPlayer.shared
    @State private var selectedTab: String = "For You"
    @State private var isSearching: Bool = false
    @State private var searchQuery: String = ""

    // Curated artists for "For You" tab (from design)
    private let curatedArtists = [
        "Royal Blood",
        "Architecture In Helsinki",
        "Superhumanoids",
        "Gengahr",
        "Father John Misty",
        "Daft Punk",
        "Scissor Sisters",
        "Thom Yorke",
        "Pink Floyd",
        "Radiohead"
    ]

    var body: some View {
        ZStack(alignment: .top) {
            // Yellow background
            Color(red: 1, green: 0.949, blue: 0) // #FFF200
                .ignoresSafeArea()

            // Scrollable Song Grid
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if iTunes.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.top, 100)
                    } else if let error = iTunes.errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                            Button("Retry") {
                                loadCuratedContent()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 1, green: 0.188, blue: 0.388))
                        }
                        .padding(.top, 100)
                    } else if iTunes.searchResults.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading music...")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                        }
                        .padding(.top, 100)
                        .onAppear {
                            loadCuratedContent()
                        }
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30),
                            GridItem(.flexible(), spacing: 30)
                        ], spacing: 60) {
                            ForEach(iTunes.searchResults) { song in
                                SongItemView(song: song) {
                                    player.play(song: song, queue: iTunes.searchResults)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 50)
                .padding(.top, 96)
                .padding(.bottom, 140)
            }

            // Top Navigation Bar
            TopNavigationBar(
                selectedTab: $selectedTab,
                isSearching: $isSearching,
                onTabChange: { _ in loadCuratedContent() }
            )

            // Search Overlay
            if isSearching {
                SearchOverlay(
                    searchQuery: $searchQuery,
                    isSearching: $isSearching,
                    onSearch: performSearch
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Sticky Player at bottom
            VStack(spacing: 0) {
                Spacer()
                StickyPlayerView()
                    .environmentObject(player)
                    .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.25), value: isSearching)
    }

    private func loadCuratedContent() {
        Task {
            do {
                switch selectedTab {
                case "For You":
                    // Load songs from curated artists
                    await iTunes.loadCuratedSongs(artists: curatedArtists)
                case "Library":
                    _ = try await iTunes.searchSongs(query: "indie rock alternative")
                case "Playlist":
                    _ = try await iTunes.searchSongs(query: "chill electronic ambient")
                case "Radio":
                    _ = try await iTunes.searchSongs(query: "popular hits 2024")
                default:
                    _ = try await iTunes.searchSongs(query: "top songs")
                }
            } catch {
                print("Load error: \(error)")
            }
        }
    }

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = false
        Task {
            do {
                _ = try await iTunes.searchSongs(query: searchQuery)
            } catch {
                print("Search error: \(error)")
            }
        }
    }
}

// MARK: - Search Overlay
struct SearchOverlay: View {
    @Binding var searchQuery: String
    @Binding var isSearching: Bool
    var onSearch: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isSearching = false
                }

            // Search box
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))

                    TextField("Search songs, artists, albums...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18))
                        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .focused($isFocused)
                        .onSubmit {
                            onSearch()
                        }

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        isSearching = false
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 1, green: 0.188, blue: 0.388))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                }
                .frame(maxWidth: 600)
            }
            .padding(.top, 100)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Top Navigation Bar (Center Aligned)
struct TopNavigationBar: View {
    @Binding var selectedTab: String
    @Binding var isSearching: Bool
    var onTabChange: (String) -> Void

    let tabs = ["For You", "Library", "Playlist", "Radio"]
    @Namespace private var tabNamespace

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 1, green: 0.949, blue: 0),
                    Color(red: 1, green: 0.949, blue: 0).opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack {
                // LEFT: Traffic lights space
                Spacer()
                    .frame(width: 80)

                Spacer()

                // CENTER: Tab Bar
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        Button {
                            withAnimation(.smooth(duration: 0.3)) {
                                selectedTab = tab
                            }
                            onTabChange(tab)
                        } label: {
                            Text(tab)
                                .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
                                .foregroundStyle(selectedTab == tab ? .white : Color(red: 0.4, green: 0.4, blue: 0.4))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background {
                                    if selectedTab == tab {
                                        Capsule()
                                            .fill(Color(red: 1, green: 0.188, blue: 0.388))
                                            .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .glassEffect(.regular, in: .capsule)

                Spacer()

                // RIGHT: Search Button & Toggle
                HStack(spacing: 16) {
                    Button {
                        isSearching = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
                            .frame(width: 36, height: 36)
                            .background {
                                Circle()
                                    .fill(Color.white.opacity(0.6))
                            }
                    }
                    .buttonStyle(.plain)

                    GlassToggle()
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 8)
        }
        .frame(height: 76)
    }
}

// MARK: - Native Glass Toggle Switch
struct GlassToggle: View {
    @State private var isOn = true

    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(.switch)
            .tint(Color(red: 1, green: 0.188, blue: 0.388))
            .labelsHidden()
    }
}

// MARK: - Song Item View
struct SongItemView: View {
    let song: Song
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    if let imageURL = song.thumbnailURL {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                placeholderImage
                            case .empty:
                                ProgressView()
                            @unknown default:
                                placeholderImage
                            }
                        }
                    } else {
                        placeholderImage
                    }
                }
                .frame(width: 180, height: 180)
                .clipShape(Circle())
                .glassEffect(
                    .regular
                        .tint(isHovered ? .white.opacity(0.1) : .clear)
                        .interactive(),
                    in: .circle
                )
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.2), value: isHovered)
                .onHover { isHovered = $0 }

                Text(song.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(white: 0.29))
                    .lineLimit(1)

                Text(song.artistName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.29))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var placeholderImage: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.4, green: 0.3, blue: 0.5),
                        Color(red: 0.3, green: 0.25, blue: 0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(50)
            }
    }
}

// MARK: - Sticky Player
struct StickyPlayerView: View {
    @EnvironmentObject var player: AudioPlayer
    @Namespace private var playerGlassNS

    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }

    var body: some View {
        HStack(spacing: 82) {
            // LEFT: Album art + info
            HStack(spacing: 25) {
                ZStack {
                    if let song = player.currentSong, let imageURL = song.thumbnailURL {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure, .empty:
                                albumPlaceholder
                            @unknown default:
                                albumPlaceholder
                            }
                        }
                    } else {
                        albumPlaceholder
                    }
                }
                .frame(width: 87, height: 87)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(player.currentSong?.name ?? "No song playing")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29))
                            .lineLimit(1)
                        Text(player.currentSong?.artistName ?? "")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29))
                            .lineLimit(1)
                    }
                    .frame(width: 180, alignment: .leading)

                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 12) {
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.glass)
                            .glassEffectID("add", in: playerGlassNS)

                            Button(action: {}) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.glass)
                            .tint(Color(red: 1, green: 0.3, blue: 0.46))
                            .glassEffectID("heart", in: playerGlassNS)

                            Button(action: {}) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.glass)
                            .glassEffectID("more", in: playerGlassNS)
                        }
                    }
                }
            }

            // CENTER: Playback controls
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 24) {
                    Button(action: {}) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("volume", in: playerGlassNS)

                    Button(action: {}) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("shuffle", in: playerGlassNS)

                    Button(action: { player.previous() }) {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("prev", in: playerGlassNS)

                    Button(action: {
                        withAnimation(.smooth(duration: 0.2)) {
                            player.togglePlayPause()
                        }
                    }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color(red: 1, green: 0.188, blue: 0.388))
                    .glassEffectID("playPause", in: playerGlassNS)

                    Button(action: { player.next() }) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("next", in: playerGlassNS)

                    Button(action: {}) {
                        Image(systemName: "repeat")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("repeat", in: playerGlassNS)
                }
            }

            // RIGHT: Progress
            VStack(spacing: 4) {
                GeometryReader { _ in
                    let trackWidth: CGFloat = 337

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(red: 0.84, green: 0.8, blue: 0.13).opacity(0.5))
                            .frame(width: trackWidth, height: 4)
                            .glassEffect(.regular, in: .capsule)

                        Capsule()
                            .fill(Color(red: 0.788, green: 0, blue: 0.176))
                            .frame(width: trackWidth * progress, height: 4)

                        Circle()
                            .fill(Color(red: 1, green: 0.3, blue: 0.46))
                            .frame(width: 14, height: 14)
                            .glassEffect(.regular.interactive(), in: .circle)
                            .offset(x: trackWidth * progress - 7)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let percentage = max(0, min(1, value.location.x / trackWidth))
                                player.seek(toPercentage: percentage)
                            }
                    )
                }
                .frame(width: 337, height: 14)

                HStack {
                    Text(player.currentTimeFormatted)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29))
                    Spacer()
                    Text(player.durationFormatted)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29))
                }
                .frame(width: 337)
            }
        }
        .padding(.horizontal, 51)
        .padding(.vertical, 17)
        .frame(maxWidth: .infinity)
        .frame(height: 125)
        .background {
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 16
                )
                .fill(.thinMaterial)

                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 16
                )
                .fill(Color(red: 1, green: 0.949, blue: 0).opacity(0.5))
                .blendMode(.multiply)
            }
        }
    }

    private var albumPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [.pink, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
    }
}

#Preview {
    MusicPlayerView()
        .frame(width: 1302, height: 827)
}
