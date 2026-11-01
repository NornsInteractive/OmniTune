package com.norns.omnitune

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.net.Uri
import android.os.Build
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File

abstract class BaseOmniTuneWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = try {
            HomeWidgetPlugin.getData(context)
        } catch (e: Throwable) {
            context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        }

        for (widgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, widgetId, prefs)
        }
    }

    abstract fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        prefs: SharedPreferences
    )

    protected fun getLaunchPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("omnitune://player")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(context, 0, intent, flags)
    }

    protected fun getMediaButtonPendingIntent(
        context: Context,
        keyCode: Int,
        requestCode: Int
    ): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setComponent(ComponentName(context, "com.ryanheise.audioservice.MediaButtonReceiver"))
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    protected fun loadArtworkBitmap(context: Context, filePath: String?, maxDim: Int = 384): Bitmap? {
        if (filePath.isNullOrBlank()) return null
        val file = File(filePath)
        if (!file.exists()) return null

        return try {
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.absolutePath, options)
            var sampleSize = 1
            while (options.outWidth / (sampleSize * 2) >= maxDim &&
                   options.outHeight / (sampleSize * 2) >= maxDim) {
                sampleSize *= 2
            }
            val decodeOptions = BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            val raw = BitmapFactory.decodeFile(file.absolutePath, decodeOptions) ?: return null
            val density = context.resources.displayMetrics.density
            roundBitmapCorners(raw, 12f, density)
        } catch (e: Throwable) {
            null
        }
    }

    private fun roundBitmapCorners(source: Bitmap, cornerRadiusDp: Float, density: Float): Bitmap {
        val radiusPx = cornerRadiusDp * density
        val output = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val rect = Rect(0, 0, source.width, source.height)
        val rectF = RectF(rect)
        canvas.drawRoundRect(rectF, radiusPx, radiusPx, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(source, rect, rect, paint)
        return output
    }

    protected fun formatTimeMs(ms: Long): String {
        if (ms <= 0) return "00:00"
        val totalSec = ms / 1000
        val min = totalSec / 60
        val sec = totalSec % 60
        return String.format("%02d:%02d", min, sec)
    }
}

/**
 * 2x2 Small Widget Provider (Compact Cover + Play/Pause Floating Action)
 */
class OmniTuneWidgetProviderSmall : BaseOmniTuneWidgetProvider() {
    override fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        prefs: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_small)

        val title = prefs.getString("widget_title", "OmniTune") ?: "OmniTune"
        val artist = prefs.getString("widget_artist", "Ready to play") ?: "Ready to play"
        val isPlaying = prefs.getBoolean("widget_is_playing", false)
        val artworkPath = prefs.getString("widget_artwork_path", null)

        views.setTextViewText(R.id.widget_small_title, title)
        views.setTextViewText(R.id.widget_small_artist, artist)

        // Pending intents
        val launchPending = getLaunchPendingIntent(context)
        views.setOnClickPendingIntent(R.id.widget_small_root, launchPending)

        val playPausePending = getMediaButtonPendingIntent(
            context,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            101
        )
        views.setOnClickPendingIntent(R.id.widget_small_play_pause, playPausePending)
        views.setImageViewResource(
            R.id.widget_small_play_pause,
            if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
        )

        // Artwork
        val bitmap = loadArtworkBitmap(context, artworkPath, 256)
        if (bitmap != null) {
            views.setImageViewBitmap(R.id.widget_small_artwork, bitmap)
        } else {
            views.setImageViewResource(R.id.widget_small_artwork, R.drawable.ic_widget_music_note)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

/**
 * 4x2 Medium Widget Provider (Landscape Bar + Full Controls + Timeline)
 */
class OmniTuneWidgetProviderMedium : BaseOmniTuneWidgetProvider() {
    override fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        prefs: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_medium)

        val title = prefs.getString("widget_title", "OmniTune") ?: "OmniTune"
        val artist = prefs.getString("widget_artist", "Ready to play") ?: "Ready to play"
        val album = prefs.getString("widget_album", "") ?: ""
        val isPlaying = prefs.getBoolean("widget_is_playing", false)
        val isFavorite = prefs.getBoolean("widget_is_favorite", false)
        val formatBadge = prefs.getString("widget_format", "Hi-Res") ?: "Hi-Res"
        val artworkPath = prefs.getString("widget_artwork_path", null)
        val positionMs = prefs.getLong("widget_position_ms", 0L)
        val durationMs = prefs.getLong("widget_duration_ms", 0L)

        views.setTextViewText(R.id.widget_medium_title, title)
        val subtitle = if (album.isNotEmpty()) "$artist · $album" else artist
        views.setTextViewText(R.id.widget_medium_artist_album, subtitle)
        views.setTextViewText(R.id.widget_medium_format, formatBadge)

        // Progress
        val progress = if (durationMs > 0) ((positionMs * 1000) / durationMs).toInt() else 0
        views.setProgressBar(R.id.widget_medium_progress, 1000, progress.coerceIn(0, 1000), false)

        // Pending intents
        val launchPending = getLaunchPendingIntent(context)
        views.setOnClickPendingIntent(R.id.widget_medium_root, launchPending)

        views.setOnClickPendingIntent(
            R.id.widget_medium_prev,
            getMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS, 201)
        )
        views.setOnClickPendingIntent(
            R.id.widget_medium_play_pause,
            getMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, 202)
        )
        views.setOnClickPendingIntent(
            R.id.widget_medium_next,
            getMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT, 203)
        )

        views.setImageViewResource(
            R.id.widget_medium_play_pause,
            if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
        )
        views.setImageViewResource(
            R.id.widget_medium_favorite,
            if (isFavorite) R.drawable.ic_favorite else R.drawable.ic_favorite_border
        )

        // Artwork
        val bitmap = loadArtworkBitmap(context, artworkPath, 256)
        if (bitmap != null) {
            views.setImageViewBitmap(R.id.widget_medium_artwork, bitmap)
        } else {
            views.setImageViewResource(R.id.widget_medium_artwork, R.drawable.ic_widget_music_note)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

/**
 * 4x4 Large Widget Provider (Music Hub + Lyric Snippet + Queue Next Preview)
 */
class OmniTuneWidgetProviderLarge : BaseOmniTuneWidgetProvider() {
    override fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        prefs: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_large)

        val title = prefs.getString("widget_title", "OmniTune") ?: "OmniTune"
        val artist = prefs.getString("widget_artist", "Ready to play") ?: "Ready to play"
        val album = prefs.getString("widget_album", "") ?: ""
        val isPlaying = prefs.getBoolean("widget_is_playing", false)
        val isFavorite = prefs.getBoolean("widget_is_favorite", false)
        val formatBadge = prefs.getString("widget_format", "Hi-Res") ?: "Hi-Res"
        val artworkPath = prefs.getString("widget_artwork_path", null)
        val lyric = prefs.getString("widget_current_lyric", "") ?: ""
        val nextTrack1 = prefs.getString("widget_queue_next1", "") ?: ""
        val nextTrack2 = prefs.getString("widget_queue_next2", "") ?: ""
        val positionMs = prefs.getLong("widget_position_ms", 0L)
        val durationMs = prefs.getLong("widget_duration_ms", 0L)

        views.setTextViewText(R.id.widget_large_title, title)
        views.setTextViewText(R.id.widget_large_artist, artist)
        views.setTextViewText(R.id.widget_large_album, album)
        views.setTextViewText(R.id.widget_large_format, formatBadge)

        // Progress & Time
        val progress = if (durationMs > 0) ((positionMs * 1000) / durationMs).toInt() else 0
        views.setProgressBar(R.id.widget_large_progress, 1000, progress.coerceIn(0, 1000), false)
        views.setTextViewText(R.id.widget_large_time_position, formatTimeMs(positionMs))
        views.setTextViewText(R.id.widget_large_time_duration, formatTimeMs(durationMs))

        // Lyric & Queue
        if (lyric.isNotEmpty()) {
            views.setViewVisibility(R.id.widget_large_lyric_container, View.VISIBLE)
            views.setTextViewText(R.id.widget_large_current_lyric, lyric)
        } else {
            views.setViewVisibility(R.id.widget_large_lyric_container, View.GONE)
        }

        if (nextTrack1.isNotEmpty()) {
            views.setViewVisibility(R.id.widget_large_queue_container, View.VISIBLE)
            views.setTextViewText(R.id.widget_large_queue_next1, "Next: $nextTrack1")
            if (nextTrack2.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_large_queue_next2, View.VISIBLE)
                views.setTextViewText(R.id.widget_large_queue_next2, "Then: $nextTrack2")
            } else {
                views.setViewVisibility(R.id.widget_large_queue_next2, View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.widget_large_queue_container, View.GONE)
        }

        // Pending intents
        val launchPending = getLaunchPendingIntent(context)
        views.setOnClickPendingIntent(R.id.widget_large_root, launchPending)

        views.setOnClickPendingIntent(
            R.id.widget_large_prev,
            getMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS, 301)
        )
        views.setOnClickPendingIntent(
            R.id.widget_large_play_pause,
            getMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, 302)
        )
        views.setOnClickPendingIntent(
            R.id.widget_large_next,
            getMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT, 303)
        )

        views.setImageViewResource(
            R.id.widget_large_play_pause,
            if (isPlaying) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
        )
        views.setImageViewResource(
            R.id.widget_large_favorite,
            if (isFavorite) R.drawable.ic_favorite else R.drawable.ic_favorite_border
        )

        // Artwork
        val bitmap = loadArtworkBitmap(context, artworkPath, 384)
        if (bitmap != null) {
            views.setImageViewBitmap(R.id.widget_large_artwork, bitmap)
        } else {
            views.setImageViewResource(R.id.widget_large_artwork, R.drawable.ic_widget_music_note)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
