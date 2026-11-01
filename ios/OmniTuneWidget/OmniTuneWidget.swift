import WidgetKit
import SwiftUI

struct OmniTuneEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let isFavorite: Bool
    let format: String
    let artworkPath: String
    let currentLyric: String
    let nextTrack1: String
    let nextTrack2: String
    let positionMs: Int
    let durationMs: Int
}

struct OmniTuneProvider: TimelineProvider {
    private let appGroupId = "group.com.norns.omnitune"

    func placeholder(in context: Context) -> OmniTuneEntry {
        OmniTuneEntry(
            date: Date(),
            title: "告白气球",
            artist: "周杰伦",
            album: "周杰伦的床边故事",
            isPlaying: true,
            isFavorite: true,
            format: "Hi-Res",
            artworkPath: "",
            currentLyric: "亲爱的 爱上你 从那天起 甜蜜的很轻易",
            nextTrack1: "晴天 · 周杰伦",
            nextTrack2: "七里香 · 周杰伦",
            positionMs: 78000,
            durationMs: 215000
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (OmniTuneEntry) -> ()) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OmniTuneEntry>) -> ()) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> OmniTuneEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let title = defaults?.string(forKey: "widget_title") ?? "OmniTune"
        let artist = defaults?.string(forKey: "widget_artist") ?? "Ready to play"
        let album = defaults?.string(forKey: "widget_album") ?? ""
        let isPlaying = defaults?.bool(forKey: "widget_is_playing") ?? false
        let isFavorite = defaults?.bool(forKey: "widget_is_favorite") ?? false
        let format = defaults?.string(forKey: "widget_format") ?? "Hi-Res"
        let artworkPath = defaults?.string(forKey: "widget_artwork_path") ?? ""
        let lyric = defaults?.string(forKey: "widget_current_lyric") ?? ""
        let nextTrack1 = defaults?.string(forKey: "widget_queue_next1") ?? ""
        let nextTrack2 = defaults?.string(forKey: "widget_queue_next2") ?? ""
        let positionMs = defaults?.integer(forKey: "widget_position_ms") ?? 0
        let durationMs = defaults?.integer(forKey: "widget_duration_ms") ?? 0

        return OmniTuneEntry(
            date: Date(),
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            isFavorite: isFavorite,
            format: format,
            artworkPath: artworkPath,
            currentLyric: lyric,
            nextTrack1: nextTrack1,
            nextTrack2: nextTrack2,
            positionMs: positionMs,
            durationMs: durationMs
        )
    }
}

struct OmniTuneWidget: Widget {
    let kind: String = "OmniTuneWidget"

    private var supportedFamilies: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            #if os(iOS)
            return [
                .systemSmall,
                .systemMedium,
                .systemLarge,
                .systemExtraLarge,
                .accessoryCircular,
                .accessoryRectangular,
                .accessoryInline
            ]
            #else
            return [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
            #endif
        } else {
            return [.systemSmall, .systemMedium, .systemLarge]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OmniTuneProvider()) { entry in
            OmniTuneWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("OmniTune")
        .description("Now playing music, lyrics, and playback controls.")
        .supportedFamilies(supportedFamilies)
    }
}
