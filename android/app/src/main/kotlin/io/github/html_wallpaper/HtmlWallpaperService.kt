package io.github.html_wallpaper

import android.annotation.SuppressLint
import android.app.WallpaperColors
import android.os.Build
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder
import android.view.View
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONArray
import kotlin.math.max
import kotlin.math.roundToInt

private data class DynamicPalette(
    val primary: Int,
    val secondary: Int,
    val tertiary: Int,
) {
    val signature: String
        get() = "$primary|$secondary|$tertiary"
}

class HtmlWallpaperService : WallpaperService() {
    companion object {
        // Keep polling infrequent for battery, but avoid very stale colors.
        private const val colorRefreshIntervalMillis = 120_000L
        @Volatile
        private var reloadGeneration = 0L
        @Volatile
        private var renderConfigGeneration = 0L
        @Volatile
        private var colorRefreshGeneration = 0L

        @Synchronized
        fun requestReload() {
            reloadGeneration = if (reloadGeneration == Long.MAX_VALUE) 1L else reloadGeneration + 1L
        }

        @Synchronized
        fun requestRenderConfigReload() {
            renderConfigGeneration = if (renderConfigGeneration == Long.MAX_VALUE) 1L else renderConfigGeneration + 1L
        }

        @Synchronized
        fun requestColorRefresh() {
            colorRefreshGeneration = if (colorRefreshGeneration == Long.MAX_VALUE) 1L else colorRefreshGeneration + 1L
        }

        fun currentReloadGeneration(): Long = reloadGeneration
        fun currentRenderConfigGeneration(): Long = renderConfigGeneration
        fun currentColorRefreshGeneration(): Long = colorRefreshGeneration

        private const val colorExtractionScript = """
            (function () {
              try {
                if (typeof window.__wallpaperDynamicPalette === 'function') {
                  return window.__wallpaperDynamicPalette();
                }
                if (typeof getCurrentColors !== 'function') {
                  return '';
                }
                var c = getCurrentColors();
                if (!c || !c.warm || !c.mid || !c.cool) {
                  return '';
                }
                return [
                  c.warm.join(','),
                  c.mid.join(','),
                  c.cool.join(',')
                ].join('|');
              } catch (e) {
                return '';
              }
            })();
        """
    }

    override fun onCreateEngine(): Engine {
        return HtmlWallpaperEngine()
    }

    inner class HtmlWallpaperEngine : Engine() {
        private val mainHandler = Handler(Looper.getMainLooper())
        private val renderTicker = object : Runnable {
            override fun run() {
                renderFrame()
                scheduleNextFrame()
            }
        }
        private val colorTicker = object : Runnable {
            override fun run() {
                refreshWallpaperColors(forceNotify = false)
                scheduleColorRefresh()
            }
        }

        private var webView: WebView? = null
        private var isVisible = false
        private var pageLoaded = false
        private var renderWidth = 1
        private var renderHeight = 1
        private var isRendering = false
        private var loadedWallpaperVersion = Long.MIN_VALUE
        private var loadingWallpaperVersion = Long.MIN_VALUE
        private var handledReloadGeneration = Long.MIN_VALUE
        private var handledRenderConfigGeneration = Long.MIN_VALUE
        private var handledColorRefreshGeneration = Long.MIN_VALUE
        private var wallpaperColors: WallpaperColors? = null
        private var lastPaletteSignature: String? = null
        private var renderScaleEnabled = false
        private var renderScale = 1.0f

        override fun onCreate(surfaceHolder: SurfaceHolder) {
            super.onCreate(surfaceHolder)
            surfaceHolder.setFormat(PixelFormat.OPAQUE)
            setTouchEventsEnabled(false)
            mainHandler.post { ensureWebView() }
        }

        @SuppressLint("SetJavaScriptEnabled")
        private fun ensureWebView() {
            if (webView != null) {
                applyRenderConfigFromPreferences(force = false)
                syncWallpaper(forceReload = false)
                return
            }

            val view = WebView(this@HtmlWallpaperService).apply {
                setBackgroundColor(Color.BLACK)
                setLayerType(View.LAYER_TYPE_HARDWARE, null)
                isHorizontalScrollBarEnabled = false
                isVerticalScrollBarEnabled = false
                overScrollMode = View.OVER_SCROLL_NEVER

                settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    allowFileAccess = true
                    allowContentAccess = true
                    loadsImagesAutomatically = true
                    mediaPlaybackRequiresUserGesture = false
                    cacheMode = WebSettings.LOAD_DEFAULT
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        safeBrowsingEnabled = false
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        offscreenPreRaster = true
                    }
                    @Suppress("DEPRECATION")
                    allowFileAccessFromFileURLs = true
                    @Suppress("DEPRECATION")
                    allowUniversalAccessFromFileURLs = true
                }

                webChromeClient = WebChromeClient()
                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        loadedWallpaperVersion = loadingWallpaperVersion
                        pageLoaded = true
                        resizeWebView()
                        renderFrame()
                        refreshWallpaperColors(forceNotify = true)
                    }
                }
            }

            webView = view
            handledReloadGeneration = currentReloadGeneration()
            handledRenderConfigGeneration = currentRenderConfigGeneration()
            handledColorRefreshGeneration = currentColorRefreshGeneration()
            applyRenderConfigFromPreferences(force = true)
            syncWallpaper(forceReload = true)
        }

        private fun syncWallpaperIfRequested() {
            val pendingGeneration = currentReloadGeneration()
            if (pendingGeneration == handledReloadGeneration) {
                return
            }
            handledReloadGeneration = pendingGeneration
            syncWallpaper(forceReload = true)
        }

        private fun syncRenderConfigIfRequested() {
            val pendingGeneration = currentRenderConfigGeneration()
            if (pendingGeneration == handledRenderConfigGeneration) {
                return
            }
            handledRenderConfigGeneration = pendingGeneration
            applyRenderConfigFromPreferences(force = true)
        }

        private fun syncColorRefreshIfRequested() {
            val pendingGeneration = currentColorRefreshGeneration()
            if (pendingGeneration == handledColorRefreshGeneration) {
                return
            }
            handledColorRefreshGeneration = pendingGeneration

            if (!isVisible) {
                return
            }
            if (!isDynamicColorsEnabled()) {
                clearWallpaperColorsIfNeeded()
                return
            }
            refreshWallpaperColors(forceNotify = true)
            scheduleColorRefresh(immediate = false)
        }

        private fun syncWallpaper(forceReload: Boolean) {
            val spec = HtmlWallpaperStorage.load(this@HtmlWallpaperService)
            if (!forceReload && pageLoaded && spec.version == loadedWallpaperVersion) {
                resizeWebView()
                renderFrame()
                return
            }
            loadWallpaperHtml(spec)
        }

        private fun loadWallpaperHtml(spec: HtmlWallpaperSpec) {
            val view = webView ?: return
            loadingWallpaperVersion = spec.version
            pageLoaded = false
            lastPaletteSignature = null
            wallpaperColors = null
            view.loadDataWithBaseURL(
                spec.baseUrl ?: "file:///android_asset/",
                spec.html,
                "text/html",
                "utf-8",
                null,
            )
        }

        private fun resizeWebView() {
            val view = webView ?: return
            if (renderWidth <= 0 || renderHeight <= 0) {
                return
            }
            val targetWidth = effectiveRenderWidth()
            val targetHeight = effectiveRenderHeight()

            val widthSpec = View.MeasureSpec.makeMeasureSpec(
                targetWidth,
                View.MeasureSpec.EXACTLY,
            )
            val heightSpec = View.MeasureSpec.makeMeasureSpec(
                targetHeight,
                View.MeasureSpec.EXACTLY,
            )
            view.measure(widthSpec, heightSpec)
            view.layout(0, 0, targetWidth, targetHeight)
        }

        private fun effectiveRenderWidth(): Int {
            if (!renderScaleEnabled) {
                return renderWidth
            }
            return max((renderWidth * renderScale).roundToInt(), 1)
        }

        private fun effectiveRenderHeight(): Int {
            if (!renderScaleEnabled) {
                return renderHeight
            }
            return max((renderHeight * renderScale).roundToInt(), 1)
        }

        private fun applyRenderConfigFromPreferences(force: Boolean) {
            val config = AndroidWallpaperPreferences.getRenderConfig(this@HtmlWallpaperService)
            val enabled = config.enabled
            val scale = config.scale.coerceIn(0.25f, 1.0f)
            val changed = enabled != renderScaleEnabled || scale != renderScale
            if (!changed && !force) {
                return
            }
            renderScaleEnabled = enabled
            renderScale = if (enabled) scale else 1.0f
            resizeWebView()
        }

        override fun onSurfaceChanged(
            holder: SurfaceHolder,
            format: Int,
            width: Int,
            height: Int,
        ) {
            super.onSurfaceChanged(holder, format, width, height)
            renderWidth = max(width, 1)
            renderHeight = max(height, 1)
            mainHandler.post {
                resizeWebView()
                renderFrame()
            }
        }

        override fun onVisibilityChanged(visible: Boolean) {
            isVisible = visible
            if (visible) {
                mainHandler.post {
                    if (webView == null) {
                        ensureWebView()
                    } else {
                        syncWallpaper(forceReload = false)
                    }
                    webView?.resumeTimers()
                    webView?.onResume()
                    scheduleNextFrame()
                    refreshWallpaperColors(forceNotify = true)
                    scheduleColorRefresh(immediate = false)
                }
            } else {
                mainHandler.removeCallbacks(renderTicker)
                mainHandler.removeCallbacks(colorTicker)
                mainHandler.post {
                    webView?.pauseTimers()
                    webView?.onPause()
                }
            }
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            mainHandler.removeCallbacks(renderTicker)
            mainHandler.removeCallbacks(colorTicker)
            super.onSurfaceDestroyed(holder)
        }

        override fun onOffsetsChanged(
            xOffset: Float,
            yOffset: Float,
            xOffsetStep: Float,
            yOffsetStep: Float,
            xPixelOffset: Int,
            yPixelOffset: Int,
        ) {
            super.onOffsetsChanged(
                xOffset,
                yOffset,
                xOffsetStep,
                yOffsetStep,
                xPixelOffset,
                yPixelOffset,
            )
            if (isVisible) {
                mainHandler.post { renderFrame() }
            }
        }

        private fun scheduleNextFrame() {
            if (!isVisible) {
                return
            }
            mainHandler.removeCallbacks(renderTicker)
            mainHandler.postDelayed(renderTicker, 33L)
        }

        private fun scheduleColorRefresh(immediate: Boolean = false) {
            mainHandler.removeCallbacks(colorTicker)
            if (!isVisible || !isDynamicColorsEnabled()) {
                return
            }
            if (immediate) {
                mainHandler.post(colorTicker)
            } else {
                mainHandler.postDelayed(colorTicker, colorRefreshIntervalMillis)
            }
        }

        private fun renderFrame() {
            val view = webView ?: return
            syncWallpaperIfRequested()
            syncRenderConfigIfRequested()
            syncColorRefreshIfRequested()
            if (!isVisible || !pageLoaded || renderWidth <= 0 || renderHeight <= 0) {
                return
            }
            if (isRendering || !surfaceHolder.surface.isValid) {
                return
            }

            isRendering = true
            var canvas = surfaceHolder.lockCanvas()
            try {
                if (canvas == null) {
                    return
                }
                canvas.drawColor(Color.BLACK)
                if (renderScaleEnabled && renderScale < 0.999f) {
                    val upscale = 1f / renderScale
                    canvas.save()
                    canvas.scale(upscale, upscale)
                    view.draw(canvas)
                    canvas.restore()
                } else {
                    view.draw(canvas)
                }
            } catch (_: Exception) {
                return
            } finally {
                if (canvas != null) {
                    surfaceHolder.unlockCanvasAndPost(canvas)
                }
                isRendering = false
            }
        }

        private fun refreshWallpaperColors(forceNotify: Boolean) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) {
                return
            }
            if (!isDynamicColorsEnabled()) {
                clearWallpaperColorsIfNeeded()
                return
            }
            val view = webView ?: return
            if (!pageLoaded) {
                return
            }
            view.evaluateJavascript(colorExtractionScript) { rawValue ->
                val palette = parsePalette(rawValue) ?: return@evaluateJavascript
                updateWallpaperColors(palette, forceNotify)
            }
        }

        private fun parsePalette(rawValue: String?): DynamicPalette? {
            val decoded = decodeJavascriptResult(rawValue)
            if (decoded.isEmpty()) {
                return null
            }

            val parts = decoded.split('|')
            if (parts.size != 3) {
                return null
            }

            val primary = parseRgb(parts[0]) ?: return null
            val secondary = parseRgb(parts[1]) ?: return null
            val tertiary = parseRgb(parts[2]) ?: return null
            return DynamicPalette(primary, secondary, tertiary)
        }

        private fun decodeJavascriptResult(rawValue: String?): String {
            if (rawValue == null || rawValue == "null") {
                return ""
            }

            val trimmed = rawValue.trim()
            if (trimmed.length >= 2 && trimmed.first() == '"' && trimmed.last() == '"') {
                return try {
                    JSONArray("[$trimmed]").getString(0)
                } catch (_: Exception) {
                    ""
                }
            }
            return trimmed
        }

        private fun parseRgb(csv: String): Int? {
            val values = csv.split(',').mapNotNull { token ->
                token.trim().toIntOrNull()
            }
            if (values.size != 3) {
                return null
            }
            return Color.rgb(
                values[0].coerceIn(0, 255),
                values[1].coerceIn(0, 255),
                values[2].coerceIn(0, 255),
            )
        }

        private fun updateWallpaperColors(palette: DynamicPalette, forceNotify: Boolean) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) {
                return
            }
            val signature = palette.signature
            if (!forceNotify && signature == lastPaletteSignature) {
                return
            }

            lastPaletteSignature = signature
            wallpaperColors = WallpaperColors(
                Color.valueOf(palette.primary),
                Color.valueOf(palette.secondary),
                Color.valueOf(palette.tertiary),
            )
            notifyColorsChanged()
        }

        private fun clearWallpaperColorsIfNeeded() {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) {
                return
            }
            if (wallpaperColors != null || lastPaletteSignature != null) {
                wallpaperColors = null
                lastPaletteSignature = null
                notifyColorsChanged()
            }
        }

        private fun isDynamicColorsEnabled(): Boolean {
            return AndroidWallpaperPreferences.isDynamicColorsEnabled(this@HtmlWallpaperService)
        }

        override fun onComputeColors(): WallpaperColors? {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) {
                return null
            }
            return if (isDynamicColorsEnabled()) wallpaperColors else null
        }

        override fun onDestroy() {
            mainHandler.removeCallbacksAndMessages(null)
            webView?.apply {
                stopLoading()
                destroy()
            }
            webView = null
            super.onDestroy()
        }
    }
}
