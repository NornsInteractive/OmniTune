import WidgetKit
import SwiftUI

// MARK: - Color Hex Extension
extension Color {
    init(hex: String, defaultColor: Color = Color(red: 20/255, green: 24/255, blue: 34/255)) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard clean.count == 6, let intVal = UInt64(clean, radix: 16) else {
            self = defaultColor
            return
        }
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

struct OmniTuneWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: OmniTuneEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            case .systemExtraLarge:
                ExtraLargeWidgetView(entry: entry)
            #if os(iOS)
            case .accessoryCircular:
                AccessoryCircularView(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularView(entry: entry)
            case .accessoryInline:
                AccessoryInlineView(entry: entry)
            #endif
            @unknown default:
                MediumWidgetView(entry: entry)
            }
        }
        .widgetURL(URL(string: "omnitune://player"))
        .containerBackground(for: .widget) {
            Color(hex: entry.backgroundColorHex, defaultColor: Color(red: 20/255, green: 24/255, blue: 34/255))
        }
    }
}

// MARK: - Helper Image Loader
struct WidgetArtworkImage: View {
    let path: String
    let size: CGFloat
    var cornerRadius: CGFloat = 10

    var body: some View {
        if !path.isEmpty, let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 31/255, green: 37/255, blue: 51/255))
                    .frame(width: size, height: size)
                Image(systemName: "music.note")
                    .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                    .font(.system(size: size * 0.4))
            }
        }
    }
}

// MARK: - Small Widget (2x2)
struct SmallWidgetView: View {
    let entry: OmniTuneEntry

    var accentColor: Color {
        Color(hex: entry.themeColorHex, defaultColor: Color(red: 88/255, green: 166/255, blue: 255/255))
    }

    var body: some View {
        ZStack {
            // Full bleed background cover if enabled
            if entry.coverFill && !entry.artworkPath.isEmpty, let uiImage = UIImage(contentsOfFile: entry.artworkPath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.55), Color.black.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                // Top row
                if entry.coverFill {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.format)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(3)

                        Text(entry.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(entry.artist)
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .center, spacing: 8) {
                        if entry.coverPosition != "right" {
                            WidgetArtworkImage(path: entry.artworkPath, size: 52)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(entry.artist)
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                                .lineLimit(1)

                            Text(entry.format)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(accentColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if entry.coverPosition == "right" {
                            WidgetArtworkImage(path: entry.artworkPath, size: 52)
                        }
                    }
                }

                Spacer(minLength: 2)

                // Bottom 3-button playback controls
                HStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 230/255, green: 237/255, blue: 243/255))

                    ZStack {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 32, height: 32)
                        Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 20/255, green: 24/255, blue: 34/255))
                    }

                    Image(systemName: "forward.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 230/255, green: 237/255, blue: 243/255))
                    Spacer()
                }
            }
            .padding(10)
        }
    }
}

// MARK: - Medium Widget (4x2)
struct MediumWidgetView: View {
    let entry: OmniTuneEntry

    var accentColor: Color {
        Color(hex: entry.themeColorHex, defaultColor: Color(red: 88/255, green: 166/255, blue: 255/255))
    }

    func formatTime(_ ms: Int) -> String {
        guard ms > 0 else { return "00:00" }
        let sec = ms / 1000
        return String(format: "%02d:%02d", sec / 60, sec % 60)
    }

    var progressPercent: Double {
        guard entry.durationMs > 0 else { return 0 }
        return min(max(Double(entry.positionMs) / Double(entry.durationMs), 0), 1)
    }

    var body: some View {
        ZStack {
            if entry.coverFill && !entry.artworkPath.isEmpty, let uiImage = UIImage(contentsOfFile: entry.artworkPath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.6), Color.black.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            HStack(spacing: 12) {
                if !entry.coverFill && entry.coverPosition != "right" {
                    WidgetArtworkImage(path: entry.artworkPath, size: 84)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center) {
                        Text(entry.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Text(entry.format)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(3)

                        Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 13))
                            .foregroundColor(entry.isFavorite ? Color(red: 255/255, green: 80/255, blue: 80/255) : Color(red: 139/255, green: 148/255, blue: 158/255))
                    }

                    Text(entry.album.isEmpty ? entry.artist : "\(entry.artist) · \(entry.album)")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                        .lineLimit(1)

                    // Timeline Progress Bar with Timestamps
                    VStack(spacing: 2) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(red: 38/255, green: 46/255, blue: 62/255))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(accentColor)
                                    .frame(width: max(geo.size.width * CGFloat(progressPercent), 3), height: 3)
                            }
                        }
                        .frame(height: 3)

                        HStack {
                            Text(formatTime(entry.positionMs))
                                .font(.system(size: 8))
                                .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                            Spacer()
                            Text(formatTime(entry.durationMs))
                                .font(.system(size: 8))
                                .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                        }
                    }
                    .padding(.vertical, 1)

                    // Playback Controls Row
                    HStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 230/255, green: 237/255, blue: 243/255))

                        ZStack {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 32, height: 32)
                            Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(red: 20/255, green: 24/255, blue: 34/255))
                        }

                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 230/255, green: 237/255, blue: 243/255))
                        Spacer()
                    }
                }

                if !entry.coverFill && entry.coverPosition == "right" {
                    WidgetArtworkImage(path: entry.artworkPath, size: 84)
                }
            }
            .padding(10)
        }
    }
}

// MARK: - Large Widget (4x4)
struct LargeWidgetView: View {
    let entry: OmniTuneEntry

    var accentColor: Color {
        Color(hex: entry.themeColorHex, defaultColor: Color(red: 88/255, green: 166/255, blue: 255/255))
    }

    func formatTime(_ ms: Int) -> String {
        guard ms > 0 else { return "00:00" }
        let sec = ms / 1000
        return String(format: "%02d:%02d", sec / 60, sec % 60)
    }

    var progressPercent: Double {
        guard entry.durationMs > 0 else { return 0 }
        return min(max(Double(entry.positionMs) / Double(entry.durationMs), 0), 1)
    }

    var body: some View {
        ZStack {
            if entry.coverFill && !entry.artworkPath.isEmpty, let uiImage = UIImage(contentsOfFile: entry.artworkPath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.65), Color.black.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                // Header: Cover + Info
                HStack(spacing: 12) {
                    if !entry.coverFill && entry.coverPosition != "right" {
                        WidgetArtworkImage(path: entry.artworkPath, size: 90)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.format)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(3)

                        Text(entry.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(entry.artist)
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 230/255, green: 237/255, blue: 243/255))
                            .lineLimit(1)

                        if !entry.album.isEmpty {
                            Text(entry.album)
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                                .lineLimit(1)
                        }

                        Text("OmniTune Hi-Fi Studio")
                            .font(.system(size: 9))
                            .foregroundColor(accentColor.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !entry.coverFill && entry.coverPosition == "right" {
                        WidgetArtworkImage(path: entry.artworkPath, size: 90)
                    }
                }

                // Timeline Bar & Labels
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(red: 38/255, green: 46/255, blue: 62/255))
                                .frame(height: 3)
                            Capsule()
                                .fill(accentColor)
                                .frame(width: max(geo.size.width * CGFloat(progressPercent), 3), height: 3)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text(formatTime(entry.positionMs))
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                        Spacer()
                        Text(formatTime(entry.durationMs))
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                    }
                }

                // Playback Controls Row
                HStack {
                    Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundColor(entry.isFavorite ? Color(red: 255/255, green: 80/255, blue: 80/255) : Color(red: 139/255, green: 148/255, blue: 158/255))

                    Spacer()

                    Image(systemName: "backward.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(red: 230/255, green: 237/255, blue: 243/255))

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 42, height: 42)
                        Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 20/255, green: 24/255, blue: 34/255))
                    }

                    Spacer()

                    Image(systemName: "forward.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(red: 230/255, green: 237/255, blue: 243/255))

                    Spacer()

                    Image(systemName: "hifispeaker.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                }
                .padding(.vertical, 2)

                Divider()
                    .background(Color(red: 32/255, green: 38/255, blue: 54/255))

                // Bottom Content Deck: Always Filled
                VStack(alignment: .leading, spacing: 6) {
                    // Lyric Sub-card
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.currentLyric.isEmpty ? "♪ OMNITUNE STUDIO" : "♪ ACTIVE LYRICS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(accentColor)

                        Text(entry.currentLyric.isEmpty ? "Pure Sound Engine · Master Quality Audio" : entry.currentLyric)
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 230/255, green: 237/255, blue: 243/255))
                            .lineLimit(2)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 26/255, green: 34/255, blue: 50/255))
                    .cornerRadius(8)

                    // Queue Sub-card
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.nextTrack1.isEmpty ? "PLAYBACK CONTEXT" : "UP NEXT IN QUEUE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))

                        Text(entry.nextTrack1.isEmpty ? "Playing current playlist loop" : "Next: \(entry.nextTrack1)")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 208/255, green: 215/255, blue: 222/255))
                            .lineLimit(1)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 26/255, green: 34/255, blue: 50/255))
                    .cornerRadius(8)
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Extra Large Widget (iPadOS Wide Hub)
struct ExtraLargeWidgetView: View {
    let entry: OmniTuneEntry

    var body: some View {
        HStack(spacing: 20) {
            LargeWidgetView(entry: entry)
                .frame(maxWidth: .infinity)

            Divider()
                .background(Color(red: 32/255, green: 38/255, blue: 54/255))

            VStack(alignment: .leading, spacing: 12) {
                Text("CURRENT LYRIC")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: entry.themeColorHex, defaultColor: Color(red: 88/255, green: 166/255, blue: 255/255)))

                Text(entry.currentLyric.isEmpty ? "No active lyrics" : entry.currentLyric)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(3)

                Spacer()

                Text("UP NEXT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))

                VStack(alignment: .leading, spacing: 6) {
                    if !entry.nextTrack1.isEmpty {
                        HStack {
                            Text("1")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                            Text(entry.nextTrack1)
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 230/255, green: 237/255, blue: 243/255))
                                .lineLimit(1)
                        }
                    }
                    if !entry.nextTrack2.isEmpty {
                        HStack {
                            Text("2")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                            Text(entry.nextTrack2)
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 139/255, green: 148/255, blue: 158/255))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
        }
    }
}

// MARK: - Lock Screen Accessories (iOS 16+)
#if os(iOS)
struct AccessoryCircularView: View {
    let entry: OmniTuneEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18))
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: OmniTuneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Image(systemName: entry.isPlaying ? "play.fill" : "pause.fill")
                    .font(.system(size: 10))
                Text(entry.title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
            }
            Text(entry.artist)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
            if !entry.currentLyric.isEmpty {
                Text(entry.currentLyric)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct AccessoryInlineView: View {
    let entry: OmniTuneEntry

    var body: some View {
        Label("\(entry.title) - \(entry.artist)", systemImage: entry.isPlaying ? "play.circle.fill" : "music.note")
    }
}
#endif
