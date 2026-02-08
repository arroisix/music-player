import SwiftUI
import AppKit

// MARK: - Models
struct MusicAlbum: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let imageName: String
}

// MARK: - Main View
struct MusicLibraryView: View {
    @State private var scrollOffset: CGFloat = 0
    @State private var currentTime: Double = 75 // 1:15
    let totalTime: Double = 201 // 3:21
    
    let albums = [
        MusicAlbum(title: "Out of the Black", artist: "Royal Blood", imageName: "album1"),
        MusicAlbum(title: "Places Like This", artist: "Architecture In Helsinki", imageName: "album2"),
        MusicAlbum(title: "Exhibitionist", artist: "Superhumanoids", imageName: "album3"),
        MusicAlbum(title: "A Dream Outside", artist: "Gengahr", imageName: "album4"),
        MusicAlbum(title: "Fear Fun", artist: "Father John Misty", imageName: "album5"),
        MusicAlbum(title: "Random Access Memories", artist: "Daft Punk", imageName: "album6"),
        MusicAlbum(title: "Magic Hour", artist: "Scissor Sisters", imageName: "album7"),
        MusicAlbum(title: "Censorsh!t", artist: "Genji Siraisi", imageName: "album8"),
        MusicAlbum(title: "The Eraser", artist: "Thom Yorke", imageName: "album9"),
        MusicAlbum(title: "The Division Bell", artist: "Pink Floyd", imageName: "album10")
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content with Yellow Background
            Color.yellow
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar with Blur Effect
                LibraryTopBar(scrollOffset: scrollOffset)
                
                // Scrollable Album Grid
                ScrollView(showsIndicators: false) {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                    }
                    .frame(height: 0)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 40),
                        GridItem(.flexible(), spacing: 40),
                        GridItem(.flexible(), spacing: 40),
                        GridItem(.flexible(), spacing: 40),
                        GridItem(.flexible(), spacing: 40)
                    ], spacing: 50) {
                        ForEach(albums) { album in
                            LibraryAlbumItem(album: album)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 30)
                    .padding(.bottom, 140) // Space for sticky player
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    scrollOffset = value
                }
            }
            
            // Sticky Player at Bottom with Blur
            MiniPlayerBar(currentTime: $currentTime, totalTime: totalTime)
        }
    }
}

// MARK: - Top Navigation Bar
struct LibraryTopBar: View {
    let scrollOffset: CGFloat

    var blurOpacity: Double {
        let opacity = min(max(-scrollOffset / 100, 0), 1)
        return opacity
    }

    var body: some View {
        ZStack {
            // Blur Background - always show blur, opacity changes based on scroll
            MacBlurView(material: .hudWindow, blendingMode: .withinWindow)
                .opacity(blurOpacity)
            
            HStack(spacing: 0) {
                // Traffic Light Buttons (macOS style)
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                }
                .padding(.leading, 20)
                
                Spacer()
                
                // Navigation Tabs
                HStack(spacing: 0) {
                    LibraryTab(title: "Now Playing", isSelected: false)
                    LibraryTab(title: "Your Library", isSelected: true)
                        .background(
                            Capsule()
                                .fill(Color.pink)
                        )
                    LibraryTab(title: "Playlist", isSelected: false)
                    LibraryTab(title: "Radio", isSelected: false)
                }
                
                Spacer()
                
                // Right Side Controls
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.3x3")
                        .foregroundColor(.gray)
                    Toggle("", isOn: .constant(false))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .gray))
                        .scaleEffect(0.8)
                }
                .padding(.trailing, 20)
            }
            .frame(height: 72)
        }
        .frame(height: 72)
    }
}

struct LibraryTab: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
    }
}

// MARK: - Album Item View
struct LibraryAlbumItem: View {
    let album: MusicAlbum

    var body: some View {
        VStack(spacing: 12) {
            // Album Cover
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 160, maxHeight: 160)
                .overlay(
                    // Placeholder for album image
                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white.opacity(0.5))
                        .padding(40)
                )
            
            // Album Title
            Text(album.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            // Artist Name
            Text(album.artist)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Bottom Player Bar
struct MiniPlayerBar: View {
    @Binding var currentTime: Double
    let totalTime: Double
    
    var body: some View {
        ZStack {
            // Blur Background
            MacBlurView(material: .hudWindow)
            
            VStack(spacing: 0) {
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background Track
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        // Progress
                        Rectangle()
                            .fill(Color.pink)
                            .frame(width: geometry.size.width * (currentTime / totalTime), height: 4)
                        
                        // Thumb
                        Circle()
                            .fill(Color.pink)
                            .frame(width: 12, height: 12)
                            .offset(x: geometry.size.width * (currentTime / totalTime) - 6)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 40)
                .padding(.top, 8)
                
                // Player Controls
                HStack(spacing: 0) {
                    // Album Info
                    HStack(spacing: 16) {
                        // Album Artwork
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.pink.opacity(0.6), .purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nocna Luka Brodova")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Mr.Rabbit")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        // Action Buttons
                        HStack(spacing: 8) {
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .foregroundColor(.gray)
                            }
                            Button(action: {}) {
                                Image(systemName: "heart")
                                    .foregroundColor(.pink)
                            }
                            Button(action: {}) {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.gray)
                            }
                        }
                        .font(.system(size: 16))
                    }
                    .padding(.leading, 40)
                    
                    Spacer()
                    
                    // Playback Controls
                    HStack(spacing: 24) {
                        Button(action: {}) {
                            Image(systemName: "speaker.wave.2")
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "shuffle")
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "backward.end.fill")
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color.pink)
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "play.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                            }
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "forward.end.fill")
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.gray)
                        }
                    }
                    .font(.system(size: 20))
                    
                    Spacer()
                    
                    // Time Display
                    HStack(spacing: 12) {
                        Text(timeString(from: currentTime))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 40, alignment: .trailing)
                        
                        Text(timeString(from: totalTime))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)
                    }
                    .padding(.trailing, 40)
                }
                .padding(.vertical, 16)
            }
        }
        .frame(height: 120)
    }
    
    func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - macOS Blur View
struct MacBlurView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview
#Preview {
    MusicLibraryView()
        .frame(width: 1400, height: 900)
}
