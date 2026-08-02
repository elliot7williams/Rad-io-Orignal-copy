//
//  ContentView.swift
//  Rad-io
//
//  Created by Elliot Williams on 2025-05-31.
//

import SwiftUI
import AVFoundation
import Accelerate
import MediaPlayer

// MARK: - Data Model
struct RadioStation: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String
    let genre: String
    let colorHex: String
    let streamURL: URL
    
    var color: Color {
        Color(hex: colorHex)
    }
    
    static let sampleStations = [
        RadioStation(name: "Electric Beats", genre: "EDM", colorHex: "#9B5DE5", streamURL: URL(string: "https://stream.zeno.fm/0r0xa792kwzuv")!),
        RadioStation(name: "Rock Legends", genre: "Rock", colorHex: "#F15BB5", streamURL: URL(string: "https://stream.zeno.fm/f3wvbbqmdg8uv")!),
        RadioStation(name: "Chill Waves", genre: "Ambient", colorHex: "#00BBF9", streamURL: URL(string: "https://stream.zeno.fm/0r0xa792kwzuv")!),
        RadioStation(name: "Hip-Hop Central", genre: "Hip-Hop", colorHex: "#FEE440", streamURL: URL(string: "https://stream.zeno.fm/f3wvbbqmdg8uv")!),
        RadioStation(name: "Jazz Lounge", genre: "Jazz", colorHex: "#00F5D4", streamURL: URL(string: "https://stream.zeno.fm/0r0xa792kwzuv")!),
        RadioStation(name: "Classical Gold", genre: "Classical", colorHex: "#FF6B6B", streamURL: URL(string: "https://stream.zeno.fm/f3wvbbqmdg8uv")!),
        RadioStation(name: "Country Roads", genre: "Country", colorHex: "#4ECDC4", streamURL: URL(string: "https://stream.zeno.fm/0r0xa792kwzuv")!),
        RadioStation(name: "Latin Beats", genre: "Latin", colorHex: "#FF9F1C", streamURL: URL(string: "https://stream.zeno.fm/f3wvbbqmdg8uv")!)
    ]
}

// MARK: - Audio Analyzer with Accelerate
class AudioAnalyzer: ObservableObject {
    @Published var magnitudes: [Float] = Array(repeating: 0.0, count: 8)
    private let fftSize = 1024
    private let bands = 8
    
    func simulateAudioAnalysis() {
        // Generate realistic audio-like values
        var simulatedMagnitudes = [Float]()
        for i in 0..<8 {
            let baseValue = Float.random(in: 0.1...0.3)
            let peakValue = sin(Float(Date().timeIntervalSince1970) * Float(i+1)) * 0.5 + 0.5
            let value = max(baseValue, peakValue)
            simulatedMagnitudes.append(value)
        }
        magnitudes = simulatedMagnitudes
    }
}

// MARK: - Radio Player with Background Support
class RadioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentStation: RadioStation?
    @Published var favoriteStations: [RadioStation] = []
    @Published var analyzer = AudioAnalyzer()
    
    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    
    override init() {
        super.init()
        loadFavorites()
        setupRemoteTransportControls()
        setupAudioSession()
    }
    
    // Setup audio session for background playback
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup error: \(error)")
        }
    }
    
    // Setup lock screen controls
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying == true {
                self?.pause()
            } else {
                self?.resume()
            }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextStation()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousStation()
            return .success
        }
    }
    
    // Update now playing info for lock screen
    private func updateNowPlayingInfo() {
        guard let station = currentStation else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = station.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = station.genre
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // Play a station
    func play(station: RadioStation) {
        stop()
        currentStation = station
        
        audioPlayer = AVPlayer(url: station.streamURL)
        audioPlayer?.play()
        isPlaying = true
        
        // Add periodic observer for audio analysis
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 20), queue: .main) { [weak self] _ in
            self?.analyzer.simulateAudioAnalysis()
        }
        
        updateNowPlayingInfo()
    }
    
    // Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        analyzer.magnitudes = Array(repeating: 0.1, count: 8)
    }
    
    // Resume playback
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    // Stop playback
    func stop() {
        audioPlayer?.pause()
        audioPlayer = nil
        isPlaying = false
        
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        analyzer.magnitudes = Array(repeating: 0.1, count: 8)
    }
    
    // Toggle play/pause
    func togglePlayback() {
        if isPlaying {
            pause()
        } else if let station = currentStation {
            play(station: station)
        }
    }
    
    // Favorites management
    func toggleFavorite(station: RadioStation) {
        if favoriteStations.contains(station) {
            favoriteStations.removeAll { $0.id == station.id }
        } else {
            favoriteStations.append(station)
        }
        saveFavorites()
    }
    
    func isFavorite(station: RadioStation) -> Bool {
        favoriteStations.contains(station)
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteStations) {
            UserDefaults.standard.set(encoded, forKey: "favoriteStations")
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "favoriteStations"),
           let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) {
            favoriteStations = decoded
        }
    }
    
    // Navigation
    func nextStation() {
        guard let current = currentStation else { return }
        let allStations = RadioStation.sampleStations
        if let index = allStations.firstIndex(of: current) {
            let nextIndex = (index + 1) % allStations.count
            play(station: allStations[nextIndex])
        }
    }
    
    func previousStation() {
        guard let current = currentStation else { return }
        let allStations = RadioStation.sampleStations
        if let index = allStations.firstIndex(of: current) {
            let prevIndex = (index - 1 + allStations.count) % allStations.count
            play(station: allStations[prevIndex])
        }
    }
}

// MARK: - UI Components
struct StationCard: View {
    let station: RadioStation
    var isPlaying: Bool
    var isFavorite: Bool
    var onPlay: () -> Void
    var onFavorite: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(station.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(station.genre)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            
            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(isFavorite ? .red : .white)
                    .padding(.trailing, 10)
            }
            
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(station.color.gradient)
                .shadow(color: station.color.opacity(0.6), radius: 10, x: 0, y: 5)
        )
    }
}

struct EqualizerView: View {
    @ObservedObject var analyzer: AudioAnalyzer
    var color: Color
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<analyzer.magnitudes.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 8, height: 30 * CGFloat(analyzer.magnitudes[index]))
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: analyzer.magnitudes[index])
            }
        }
        .frame(height: 30)
    }
}

struct PlayerControls: View {
    @ObservedObject var player: RadioPlayer
    
    var body: some View {
        VStack {
            if let station = player.currentStation {
                HStack {
                    VStack(alignment: .leading) {
                        Text(station.name)
                            .font(.title3.bold())
                            .lineLimit(1)
                        Text(station.genre)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if player.isPlaying {
                        EqualizerView(analyzer: player.analyzer, color: station.color)
                            .frame(width: 100)
                    }
                    
                    Button(action: player.togglePlayback) {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(station.color)
                    }
                }
                
                HStack {
                    Button(action: player.previousStation) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(station.color)
                    }
                    .padding(.trailing, 30)
                    
                    Button(action: {
                        player.toggleFavorite(station: station)
                    }) {
                        Image(systemName: player.isFavorite(station: station) ? "heart.fill" : "heart")
                            .font(.title)
                            .foregroundColor(player.isFavorite(station: station) ? .red : station.color)
                    }
                    
                    Button(action: player.nextStation) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(station.color)
                    }
                    .padding(.leading, 30)
                }
                .padding(.top, 10)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal)
    }
}

struct StationListView: View {
    @ObservedObject var player: RadioPlayer
    var stations: [RadioStation]
    var title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ForEach(stations) { station in
                StationCard(
                    station: station,
                    isPlaying: player.currentStation == station && player.isPlaying,
                    isFavorite: player.isFavorite(station: station),
                    onPlay: { player.play(station: station) },
                    onFavorite: { player.toggleFavorite(station: station) }
                )
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Main View
struct RadioView: View {
    @StateObject private var player = RadioPlayer()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [.indigo, .black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                Text("RADIANT RADIO")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .padding(.top, 30)
                    .shadow(color: .purple, radius: 10)
                
                // Tab selector
                HStack {
                    TabButton(title: "All Stations", index: 0, selectedTab: $selectedTab)
                    TabButton(title: "Favorites", index: 1, selectedTab: $selectedTab)
                    TabButton(title: "Playing", index: 2, selectedTab: $selectedTab)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                // Tab content
                TabView(selection: $selectedTab) {
                    ScrollView {
                        StationListView(
                            player: player,
                            stations: RadioStation.sampleStations,
                            title: "All Stations"
                        )
                        .padding(.top, 20)
                    }
                    .tag(0)
                    
                    ScrollView {
                        if player.favoriteStations.isEmpty {
                            Text("No favorites yet\nTap the heart icon to add stations")
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.top, 100)
                        } else {
                            StationListView(
                                player: player,
                                stations: player.favoriteStations,
                                title: "Favorite Stations"
                            )
                            .padding(.top, 20)
                        }
                    }
                    .tag(1)
                    
                    ScrollView {
                        if let currentStation = player.currentStation {
                            VStack {
                                ZStack {
                                    Circle()
                                        .fill(currentStation.color.gradient)
                                        .frame(width: 200, height: 200)
                                        .shadow(color: currentStation.color.opacity(0.6), radius: 20)
                                    
                                    if player.isPlaying {
                                        EqualizerView(analyzer: player.analyzer, color: .white)
                                            .frame(width: 150, height: 60)
                                    } else {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 60))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.top, 50)
                                
                                Text(currentStation.name)
                                    .font(.title.bold())
                                    .foregroundColor(.white)
                                    .padding(.top, 20)
                                
                                Text(currentStation.genre)
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.top, 5)
                                
                                HStack(spacing: 30) {
                                    Button(action: player.previousStation) {
                                        Image(systemName: "backward.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Circle().fill(currentStation.color))
                                    }
                                    
                                    Button(action: player.togglePlayback) {
                                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Circle().fill(currentStation.color))
                                    }
                                    
                                    Button(action: player.nextStation) {
                                        Image(systemName: "forward.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Circle().fill(currentStation.color))
                                    }
                                }
                                .padding(.top, 30)
                                
                                Button(action: {
                                    player.toggleFavorite(station: currentStation)
                                }) {
                                    HStack {
                                        Image(systemName: player.isFavorite(station: currentStation) ? "heart.fill" : "heart")
                                        Text(player.isFavorite(station: currentStation) ? "Remove from Favorites" : "Add to Favorites")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 15).fill(currentStation.color))
                                }
                                .padding(.top, 20)
                            }
                            .padding()
                        } else {
                            Text("No station playing\nSelect a station to start listening")
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.top, 150)
                        }
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Player controls at bottom
                PlayerControls(player: player)
                    .padding(.bottom, 30)
                    .padding(.top, 10)
            }
        }
        .onAppear {
            // Set background audio session
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Audio session setup error: \(error)")
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let index: Int
    @Binding var selectedTab: Int
    
    var body: some View {
        Button(action: {
            selectedTab = index
        }) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    selectedTab == index ?
                    RoundedRectangle(cornerRadius: 15).fill(Color.purple.opacity(0.3)) :
                        RoundedRectangle(cornerRadius: 15).fill(Color.clear)
                )
        }
    }
}

// MARK: - Helper Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
struct RadioView_Previews: PreviewProvider {
    static var previews: some View {
        RadioView()
            .preferredColorScheme(.dark)
    }
}
