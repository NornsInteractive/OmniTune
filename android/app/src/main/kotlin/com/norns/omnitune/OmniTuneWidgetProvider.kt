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
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File
import kotlin.math.roundToInt

abstract class BaseOmniTuneWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = try {
                HomeWidgetPlugin.getData(context)
            } catch (e: Throwable) {
                context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            }

            for (widgetId in appWidgetIds) {
                try {
                    updateAppWidget(context, appWidgetManager, widgetId, prefs)
                } catch (e: Throwable) {
                    Log.e("OmniTuneWidget", "Error updating widget $widgetId", e)
                }
            }
        } catch (e: Throwable) {
            Log.e("OmniTuneWidget", "Error in onUpdate", e)
        }
    }

    abstract fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        prefs: SharedPreferences
    )

    protected fun getLongOrInt(prefs: SharedPreferences, key: String, default: Long = 0L): Long {
        return try {
            prefs.getLong(key, default)
        } catch (e: ClassCastException) {
            try {
                prefs.getInt(key, default.toInt()).toLong()
            } catch (e2: Throwable) {
                default
            }
        } catch (e: Throwable) {
            default
        }
    }

    protected fun getFloatSafe(prefs: SharedPreferences, key: String, default: Float = 0.5f): Float {
        return try {
            val all = prefs.all
            val value = all[key]
            if (value != null) {
                when (value) {
                    is Float -> return value
                    is Double -> return value.toFloat()
                    is Long -> {
                        return if (prefs.getBoolean("home_widget.double.$key", false)) {
                            java.lang.Double.longBitsToDouble(value).toFloat()
                        } else {
                            value.toFloat()
                        }
                    }
                    is Int -> return value.toFloat()
                    is String -> return value.toFloatOrNull() ?: default
                }
            }
            val pctKey = "${key}_pct"
            val pctValue = all[pctKey]
            if (pctValue is Number) {
                return (pctValue.toFloat() / 100.0f).coerceIn(0.0f, 1.0f)
            }
            default
        } catch (e: Throwable) {
            default
        }
    }

    protected fun getBooleanSafe(prefs: SharedPreferences, key: String, default: Boolean): Boolean {
        return try {
            if (prefs.contains(key)) prefs.getBoolean(key, default) else default
        } catch (e: Throwable) {
            default
        }
    }

    protected fun parseColorHex(hex: String?, defaultColor: Int): Int {
        if (hex.isNullOrBlank()) return defaultColor
        return try {
            val cleanHex = if (hex.startsWith("#")) hex else "#$hex"
            Color.parseColor(cleanHex)
        } catch (e: Throwable) {
            defaultColor
        }
    }

    protected fun isColorLight(color: Int): Boolean {
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        val luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
        return luminance > 0.5
    }

    protected fun getLaunchPendingIntent(context: Context): PendingIntent {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
        launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(context, 0, launchIntent, flags)
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

    protected fun loadArtworkBitmap(
        context: Context,
        filePath: String?,
        maxDim: Int = 256,
        cornerRadiusDp: Float = 12f
    ): Bitmap? {
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
            roundBitmapCorners(raw, cornerRadiusDp, density)
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
 * 2x2 Small Widget Provider (Previous + Play/Pause + Next, Position & Fill & Colors)
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
        val formatBadge = prefs.getString("widget_format", "Hi-Res") ?: "Hi-Res"
        val artworkPath = prefs.getString("widget_artwork_path", null)
        val lyric = prefs.getString("widget_current_lyric", "") ?: ""

        val coverPos = prefs.getString("widget_small_cover_pos", prefs.getString("widget_cover_pos", "left")) ?: "left"
        val coverFill = getBooleanSafe(prefs, "widget_small_cover_fill", getBooleanSafe(prefs, "widget_cover_fill", true))
        val coverOpacity = getFloatSafe(prefs, "widget_small_cover_opacity", getFloatSafe(prefs, "widget_cover_opacity", 0.5f))
        val bgColor = parseColorHex(prefs.getString("widget_small_bg_color", prefs.getString("widget_bg_color", "#121620")), 0xFF121620.toInt())
        val themeColor = parseColorHex(prefs.getString("widget_small_theme_color", prefs.getString("widget_theme_color", "#58A6FF")), 0xFF58A6FF.toInt())
        val showLyrics = getBooleanSafe(prefs, "widget_small_show_lyrics", getBooleanSafe(prefs, "widget_show_lyrics", true))

        views.setTextViewText(R.id.widget_small_title, title)
        views.setTextViewText(R.id.widget_small_artist, artist)
        views.setTextViewText(R.id.widget_small_format, formatBadge)
        views.setTextColor(R.id.widget_small_format, themeColor)

        // Tint base background
        views.setInt(R.id.widget_small_bg, "setColorFilter", bgColor)

        // Pending intents
        val launchPending = getLaunchPendingIntent(context)
        views.setOnClickPendingIntent(R.id.widget_small_root, launchPending)

        views.setOnClickPendingIntent(
            R.id.widget_small_prev,
            getMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS, 101)
        )
        views.setOnClickPendingIntent(
            R.id.widget_small_play_pause,
            getMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, 102)
        )
        views.setOnClickPendingIntent(
            R.id.widget_small_next,
            getMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT, 103)
        )

        // Play/Pause button styling
        views.setInt(R.id.widget_small_play_pause_bg, "setColorFilter", themeColor)
        val isLight = isColorLight(themeColor)
        val playIconRes = if (isPlaying) {
            if (isLight) R.drawable.ic_widget_pause_dark else R.drawable.ic_widget_pause
        } else {
            if (isLight) R.drawable.ic_widget_play_dark else R.drawable.ic_widget_play
        }
        views.setImageViewResource(R.id.widget_small_play_pause_icon, playIconRes)

        // Dynamic Lyrics row
        if (showLyrics && lyric.isNotBlank()) {
            views.setViewVisibility(R.id.widget_small_lyric, View.VISIBLE)
            views.setTextViewText(R.id.widget_small_lyric, "♪ $lyric")
            views.setTextColor(R.id.widget_small_lyric, themeColor)
        } else {
            views.setViewVisibility(R.id.widget_small_lyric, View.GONE)
        }

        // Artwork handling: full-bleed fill vs side placement
        val bitmap = loadArtworkBitmap(context, artworkPath, 256, if (coverFill) 20f else 12f)
        if (coverFill && bitmap != null) {
            views.setViewVisibility(R.id.widget_small_bg_cover, View.VISIBLE)
            views.setImageViewBitmap(R.id.widget_small_bg_cover, bitmap)
            if (coverOpacity > 0.01f) {
                views.setViewVisibility(R.id.widget_small_scrim, View.VISIBLE)
                val alphaInt = (coverOpacity.coerceIn(0.0f, 1.0f) * 255f).roundToInt().coerceIn(0, 255)
                views.setInt(R.id.widget_small_scrim, "setImageAlpha", alphaInt)
                views.setFloat(R.id.widget_small_scrim, "setAlpha", coverOpacity.coerceIn(0.0f, 1.0f))
            } else {
                views.setViewVisibility(R.id.widget_small_scrim, View.GONE)
            }
            views.setViewVisibility(R.id.widget_small_artwork_left, View.GONE)
            views.setViewVisibility(R.id.widget_small_artwork_right, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_small_bg_cover, View.GONE)
            views.setViewVisibility(R.id.widget_small_scrim, View.GONE)
            if (coverPos == "right") {
                views.setViewVisibility(R.id.widget_small_artwork_left, View.GONE)
                views.setViewVisibility(R.id.widget_small_artwork_right, View.VISIBLE)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_small_artwork_right, bitmap)
                } else {
                    views.setImageViewResource(R.id.widget_small_artwork_right, R.drawable.ic_widget_music_note)
                }
            } else {
                views.setViewVisibility(R.id.widget_small_artwork_left, View.VISIBLE)
                views.setViewVisibility(R.id.widget_small_artwork_right, View.GONE)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_small_artwork_left, bitmap)
                } else {
                    views.setImageViewResource(R.id.widget_small_artwork_left, R.drawable.ic_widget_music_note)
                }
            }
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

/**
 * 4x2 Medium Widget Provider (Full Bleed Content + Timeline + Dual Position Cover)
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
        val lyric = prefs.getString("widget_current_lyric", "") ?: ""
        val positionMs = getLongOrInt(prefs, "widget_position_ms", 0L)
        val durationMs = getLongOrInt(prefs, "widget_duration_ms", 0L)

        val coverPos = prefs.getString("widget_medium_cover_pos", prefs.getString("widget_cover_pos", "left")) ?: "left"
        val coverFill = getBooleanSafe(prefs, "widget_medium_cover_fill", getBooleanSafe(prefs, "widget_cover_fill", true))
        val coverOpacity = getFloatSafe(prefs, "widget_medium_cover_opacity", getFloatSafe(prefs, "widget_cover_opacity", 0.5f))
        val bgColor = parseColorHex(prefs.getString("widget_medium_bg_color", prefs.getString("widget_bg_color", "#121620")), 0xFF121620.toInt())
        val themeColor = parseColorHex(prefs.getString("widget_medium_theme_color", prefs.getString("widget_theme_color", "#58A6FF")), 0xFF58A6FF.toInt())
        val showLyrics = getBooleanSafe(prefs, "widget_medium_show_lyrics", getBooleanSafe(prefs, "widget_show_lyrics", true))

        views.setTextViewText(R.id.widget_medium_title, title)
        val subtitle = if (album.isNotEmpty()) "$artist · $album" else artist
        views.setTextViewText(R.id.widget_medium_artist_album, subtitle)
        views.setTextViewText(R.id.widget_medium_format, formatBadge)
        views.setTextColor(R.id.widget_medium_format, themeColor)

        // Tint base background
        views.setInt(R.id.widget_medium_bg, "setColorFilter", bgColor)

        // Progress & Timestamps
        val progress = if (durationMs > 0) ((positionMs * 1000) / durationMs).toInt() else 0
        views.setProgressBar(R.id.widget_medium_progress, 1000, progress.coerceIn(0, 1000), false)
        views.setTextViewText(R.id.widget_medium_time_pos, formatTimeMs(positionMs))
        views.setTextViewText(R.id.widget_medium_time_dur, formatTimeMs(durationMs))

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
        views.setOnClickPendingIntent(
            R.id.widget_medium_favorite,
            launchPending
        )

        // Play/Pause button styling
        views.setInt(R.id.widget_medium_play_pause_bg, "setColorFilter", themeColor)
        val isLight = isColorLight(themeColor)
        val playIconRes = if (isPlaying) {
            if (isLight) R.drawable.ic_widget_pause_dark else R.drawable.ic_widget_pause
        } else {
            if (isLight) R.drawable.ic_widget_play_dark else R.drawable.ic_widget_play
        }
        views.setImageViewResource(R.id.widget_medium_play_pause_icon, playIconRes)

        views.setImageViewResource(
            R.id.widget_medium_favorite,
            if (isFavorite) R.drawable.ic_widget_favorite_active else R.drawable.ic_widget_favorite_inactive
        )

        // Dynamic Lyrics row
        if (showLyrics && lyric.isNotBlank()) {
            views.setViewVisibility(R.id.widget_medium_lyric, View.VISIBLE)
            views.setTextViewText(R.id.widget_medium_lyric, "♪ $lyric")
            views.setTextColor(R.id.widget_medium_lyric, themeColor)
        } else {
            views.setViewVisibility(R.id.widget_medium_lyric, View.GONE)
        }

        // Artwork handling: full-bleed fill vs side placement
        val bitmap = loadArtworkBitmap(context, artworkPath, 256, if (coverFill) 20f else 12f)
        if (coverFill && bitmap != null) {
            views.setViewVisibility(R.id.widget_medium_bg_cover, View.VISIBLE)
            views.setImageViewBitmap(R.id.widget_medium_bg_cover, bitmap)
            if (coverOpacity > 0.01f) {
                views.setViewVisibility(R.id.widget_medium_scrim, View.VISIBLE)
                val alphaInt = (coverOpacity.coerceIn(0.0f, 1.0f) * 255f).roundToInt().coerceIn(0, 255)
                views.setInt(R.id.widget_medium_scrim, "setImageAlpha", alphaInt)
                views.setFloat(R.id.widget_medium_scrim, "setAlpha", coverOpacity.coerceIn(0.0f, 1.0f))
            } else {
                views.setViewVisibility(R.id.widget_medium_scrim, View.GONE)
            }
            views.setViewVisibility(R.id.widget_medium_artwork_left, View.GONE)
            views.setViewVisibility(R.id.widget_medium_artwork_right, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_medium_bg_cover, View.GONE)
            views.setViewVisibility(R.id.widget_medium_scrim, View.GONE)
            if (coverPos == "right") {
                views.setViewVisibility(R.id.widget_medium_artwork_left, View.GONE)
                views.setViewVisibility(R.id.widget_medium_artwork_right, View.VISIBLE)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_medium_artwork_right, bitmap)
                } else {
                    views.setImageViewResource(R.id.widget_medium_artwork_right, R.drawable.ic_widget_music_note)
                }
            } else {
                views.setViewVisibility(R.id.widget_medium_artwork_left, View.VISIBLE)
                views.setViewVisibility(R.id.widget_medium_artwork_right, View.GONE)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_medium_artwork_left, bitmap)
                } else {
                    views.setImageViewResource(R.id.widget_medium_artwork_left, R.drawable.ic_widget_music_note)
                }
            }
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

/**
 * 4x4 Large Widget Provider (Music Hub + Complete Content Filling + Dual Position Cover)
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
        val positionMs = getLongOrInt(prefs, "widget_position_ms", 0L)
        val durationMs = getLongOrInt(prefs, "widget_duration_ms", 0L)

        val coverPos = prefs.getString("widget_large_cover_pos", prefs.getString("widget_cover_pos", "left")) ?: "left"
        val coverFill = getBooleanSafe(prefs, "widget_large_cover_fill", getBooleanSafe(prefs, "widget_cover_fill", true))
        val coverOpacity = getFloatSafe(prefs, "widget_large_cover_opacity", getFloatSafe(prefs, "widget_cover_opacity", 0.5f))
        val bgColor = parseColorHex(prefs.getString("widget_large_bg_color", prefs.getString("widget_bg_color", "#121620")), 0xFF121620.toInt())
        val themeColor = parseColorHex(prefs.getString("widget_large_theme_color", prefs.getString("widget_theme_color", "#58A6FF")), 0xFF58A6FF.toInt())
        val showLyrics = getBooleanSafe(prefs, "widget_large_show_lyrics", getBooleanSafe(prefs, "widget_show_lyrics", true))

        views.setTextViewText(R.id.widget_large_title, title)
        views.setTextViewText(R.id.widget_large_artist, artist)
        views.setTextViewText(R.id.widget_large_album, album)
        views.setTextViewText(R.id.widget_large_format, formatBadge)
        views.setTextColor(R.id.widget_large_format, themeColor)
        views.setTextColor(R.id.widget_large_lyric_label, themeColor)
        views.setTextColor(R.id.widget_large_quality_tag, themeColor)

        // Tint base background
        views.setInt(R.id.widget_large_bg, "setColorFilter", bgColor)

        // Progress & Time
        val progress = if (durationMs > 0) ((positionMs * 1000) / durationMs).toInt() else 0
        views.setProgressBar(R.id.widget_large_progress, 1000, progress.coerceIn(0, 1000), false)
        views.setTextViewText(R.id.widget_large_time_position, formatTimeMs(positionMs))
        views.setTextViewText(R.id.widget_large_time_duration, formatTimeMs(durationMs))

        // Dynamic Lyrics Card (Card 1)
        if (showLyrics) {
            views.setViewVisibility(R.id.widget_large_lyric_card, View.VISIBLE)
            if (lyric.isNotBlank()) {
                views.setTextViewText(R.id.widget_large_lyric_label, "♪ ACTIVE LYRICS")
                views.setTextViewText(R.id.widget_large_current_lyric, lyric)
            } else {
                views.setTextViewText(R.id.widget_large_lyric_label, "♪ OMNITUNE STUDIO")
                views.setTextViewText(R.id.widget_large_current_lyric, "Pure Sound Engine · Master Quality Audio")
            }
        } else {
            views.setViewVisibility(R.id.widget_large_lyric_card, View.GONE)
        }

        // Queue Hub (Card 2)
        if (nextTrack1.isNotBlank()) {
            views.setTextViewText(R.id.widget_large_queue_label, "UP NEXT IN QUEUE")
            views.setTextViewText(R.id.widget_large_queue_next1, "Next: $nextTrack1")
            if (nextTrack2.isNotBlank()) {
                views.setTextViewText(R.id.widget_large_queue_next2, "Then: $nextTrack2")
            } else {
                views.setTextViewText(R.id.widget_large_queue_next2, "Playback: Normal Loop Mode")
            }
        } else {
            views.setTextViewText(R.id.widget_large_queue_label, "PLAYBACK CONTEXT")
            views.setTextViewText(R.id.widget_large_queue_next1, "Playing from Current Audio Stream")
            views.setTextViewText(R.id.widget_large_queue_next2, "OmniTune High-Resolution Processing")
        }

        // Pending intents
        val launchPending = getLaunchPendingIntent(context)
        views.setOnClickPendingIntent(R.id.widget_large_root, launchPending)
        views.setOnClickPendingIntent(R.id.widget_large_app_icon, launchPending)
        views.setOnClickPendingIntent(R.id.widget_large_favorite, launchPending)

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

        // Play/Pause button styling
        views.setInt(R.id.widget_large_play_pause_bg, "setColorFilter", themeColor)
        val isLight = isColorLight(themeColor)
        val playIconRes = if (isPlaying) {
            if (isLight) R.drawable.ic_widget_pause_dark else R.drawable.ic_widget_pause
        } else {
            if (isLight) R.drawable.ic_widget_play_dark else R.drawable.ic_widget_play
        }
        views.setImageViewResource(R.id.widget_large_play_pause_icon, playIconRes)

        views.setImageViewResource(
            R.id.widget_large_favorite,
            if (isFavorite) R.drawable.ic_widget_favorite_active else R.drawable.ic_widget_favorite_inactive
        )

        // Artwork handling: full-bleed fill vs side placement
        val bitmap = loadArtworkBitmap(context, artworkPath, 256, if (coverFill) 20f else 12f)
        if (coverFill && bitmap != null) {
            views.setViewVisibility(R.id.widget_large_bg_cover, View.VISIBLE)
            views.setImageViewBitmap(R.id.widget_large_bg_cover, bitmap)
            if (coverOpacity > 0.01f) {
                views.setViewVisibility(R.id.widget_large_scrim, View.VISIBLE)
                val alphaInt = (coverOpacity.coerceIn(0.0f, 1.0f) * 255f).roundToInt().coerceIn(0, 255)
                views.setInt(R.id.widget_large_scrim, "setImageAlpha", alphaInt)
                views.setFloat(R.id.widget_large_scrim, "setAlpha", coverOpacity.coerceIn(0.0f, 1.0f))
            } else {
                views.setViewVisibility(R.id.widget_large_scrim, View.GONE)
            }
            views.setViewVisibility(R.id.widget_large_artwork_left, View.GONE)
            views.setViewVisibility(R.id.widget_large_artwork_right, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_large_bg_cover, View.GONE)
            views.setViewVisibility(R.id.widget_large_scrim, View.GONE)
            if (coverPos == "right") {
                views.setViewVisibility(R.id.widget_large_artwork_left, View.GONE)
                views.setViewVisibility(R.id.widget_large_artwork_right, View.VISIBLE)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_large_artwork_right, bitmap)
                } else {
                    views.setImageViewResource(R.id.widget_large_artwork_right, R.drawable.ic_widget_music_note)
                }
            } else {
                views.setViewVisibility(R.id.widget_large_artwork_left, View.VISIBLE)
                views.setViewVisibility(R.id.widget_large_artwork_right, View.GONE)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_large_artwork_left, bitmap)
                } else {
                    views.setImageViewResource(R.id.widget_large_artwork_left, R.drawable.ic_widget_music_note)
                }
            }
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
