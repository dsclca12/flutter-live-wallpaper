package io.github.html_wallpaper

import android.annotation.SuppressLint
import android.app.ActivityManager
import android.app.WallpaperColors
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
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
import org.json.JSONObject
import java.io.BufferedReader
import java.io.FileReader
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

        // 静态壁纸大幅降低刷新频率以节省内存与电量
        private const val ANIM_FRAME_INTERVAL_MS = 33L          // ~30fps 用于动态壁纸
        private const val STATIC_FRAME_INTERVAL_MS = 5000L      // 5s 用于静态壁纸
        private const val SYSTEM_INFO_INTERVAL_MS = 15000L      // 15s 默认系统信息
        private const val STATIC_SYSTEM_INFO_INTERVAL_MS = 60000L // 60s 静态壁纸系统信息
        private const val COLOR_REFRESH_INTERVAL_MS = 120_000L  // 2min 动态色彩
        private const val STATIC_COLOR_REFRESH_INTERVAL_MS = 300_000L // 5min 静态色彩

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
        private val systemInfoTicker = object : Runnable {
            override fun run() {
                pushSystemInfo()
                scheduleSystemInfoRefresh()
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
        // 是否检测到静态壁纸标记（HTML内含 window.__wallpaperStatic）
        private var isStaticWallpaper = false

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
                    domStorageEnabled = false     // 壁纸不需要 DOM Storage，禁用可减少内存
                    databaseEnabled = false       // 禁用 Web SQL
                    allowFileAccess = true
                    allowContentAccess = true
                    loadsImagesAutomatically = true
                    mediaPlaybackRequiresUserGesture = false
                    cacheMode = WebSettings.LOAD_CACHE_ELSE_NETWORK
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        safeBrowsingEnabled = false
                    }
                    // 壁纸无滚动场景，offscreenPreRaster 徒增内存，仅在非静态时开启
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        offscreenPreRaster = false
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
                        // 检测静态壁纸标记
                        detectStaticWallpaper()
                        resizeWebView()
                        renderFrame()
                        refreshWallpaperColors(forceNotify = true)
                        // 启动系统信息推送
                        pushSystemInfo()
                        scheduleSystemInfoRefresh()
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

        private fun detectStaticWallpaper() {
            val html = HtmlWallpaperStorage.load(this@HtmlWallpaperService).html
            isStaticWallpaper = html.contains("__wallpaperStatic") ||
                                html.contains("window.__wallpaperStatic")
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
                mainHandler.removeCallbacks(systemInfoTicker)
                mainHandler.post {
                    webView?.pauseTimers()
                    webView?.onPause()
                }
            }
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            mainHandler.removeCallbacks(renderTicker)
            mainHandler.removeCallbacks(colorTicker)
            mainHandler.removeCallbacks(systemInfoTicker)
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
            val interval = if (isStaticWallpaper) STATIC_FRAME_INTERVAL_MS else ANIM_FRAME_INTERVAL_MS
            mainHandler.postDelayed(renderTicker, interval)
        }

        private fun scheduleColorRefresh(immediate: Boolean = false) {
            mainHandler.removeCallbacks(colorTicker)
            if (!isVisible || !isDynamicColorsEnabled()) {
                return
            }
            val interval = if (isStaticWallpaper) STATIC_COLOR_REFRESH_INTERVAL_MS else COLOR_REFRESH_INTERVAL_MS
            if (immediate) {
                mainHandler.post(colorTicker)
            } else {
                mainHandler.postDelayed(colorTicker, interval)
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

        // ========== 系统信息推送 ==========
        
        private fun scheduleSystemInfoRefresh(immediate: Boolean = false) {
            mainHandler.removeCallbacks(systemInfoTicker)
            if (!isVisible) return
            // 静态壁纸大幅降低推送频率，减少 JS 执行与内存波动
            val delay = if (immediate) 0L else (
                if (isStaticWallpaper) STATIC_SYSTEM_INFO_INTERVAL_MS else SYSTEM_INFO_INTERVAL_MS
            )
            mainHandler.postDelayed(systemInfoTicker, delay)
        }
        
        private fun pushSystemInfo() {
            val view = webView ?: return
            if (!pageLoaded || !isVisible) return
            
            val batteryLevel = getBatteryLevel()
            val isCharging = getIsCharging()
            val batteryState = getBatteryState()
            val cpuUsage = getCpuUsage()
            val totalMemory = getTotalMemory()
            val usedMemory = getUsedMemory()
            val memoryUsagePercent = if (totalMemory != null && totalMemory > 0) (usedMemory * 100.0 / totalMemory) else null
            val wifiName = getWifiName()
            val wifiIP = getWifiIP()
            val networkType = getNetworkType()
            val timestamp = System.currentTimeMillis()
            
            val config = JSONObject().apply {
                put("batteryLevel", batteryLevel)
                put("isCharging", isCharging)
                put("batteryState", batteryState)
                put("cpuUsage", cpuUsage)
                put("totalMemory", totalMemory)
                put("usedMemory", usedMemory)
                put("memoryUsagePercent", memoryUsagePercent)
                put("wifiName", wifiName)
                put("wifiIP", wifiIP)
                put("networkType", networkType)
                put("timestamp", timestamp)
            }
            
            val script = """
                try {
                    if (typeof window.setWallpaperConfig === 'function') {
                        window.setWallpaperConfig(${config.toString()});
                    }
                } catch(e) {
                    console.error('System info push failed:', e);
                }
            """.trimIndent()
            
            view.evaluateJavascript(script, null)
        }
        
        private fun getBatteryLevel(): Double? {
            return try {
                val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                if (level > 0) level.toDouble() else null
            } catch (e: Exception) {
                null
            }
        }
        
        private fun getIsCharging(): Boolean? {
            return try {
                val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                val status = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_STATUS)
                when (status) {
                    BatteryManager.BATTERY_STATUS_CHARGING,
                    BatteryManager.BATTERY_STATUS_FULL -> true
                    BatteryManager.BATTERY_STATUS_DISCHARGING,
                    BatteryManager.BATTERY_STATUS_NOT_CHARGING -> false
                    else -> null
                }
            } catch (e: Exception) {
                null
            }
        }
        
        private fun getBatteryState(): String? {
            return try {
                val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                val status = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_STATUS)
                when (status) {
                    BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
                    BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
                    BatteryManager.BATTERY_STATUS_FULL -> "full"
                    BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "connected_not_charging"
                    else -> null
                }
            } catch (e: Exception) {
                null
            }
        }
        
        private fun getCpuUsage(): Double? {
            return try {
                // 读取 /proc/stat 计算 CPU 使用率
                val reader = BufferedReader(FileReader("/proc/stat"))
                val line = reader.readLine()
                reader.close()
                
                if (line != null && line.startsWith("cpu ")) {
                    val parts = line.split(Regex("\\s+")).filter { it.isNotEmpty() }
                    if (parts.size >= 5) {
                        val user = parts[1].toLong()
                        val nice = parts[2].toLong()
                        val system = parts[3].toLong()
                        val idle = parts[4].toLong()
                        val iowait = if (parts.size > 5) parts[5].toLong() else 0
                        val irq = if (parts.size > 6) parts[6].toLong() else 0
                        val softirq = if (parts.size > 7) parts[7].toLong() else 0
                        val steal = if (parts.size > 8) parts[8].toLong() else 0
                        
                        val totalIdle = idle + iowait
                        val totalUsage = user + nice + system + irq + softirq + steal
                        val total = totalIdle + totalUsage
                        
                        if (total > 0) {
                            return (totalUsage * 100.0 / total)
                        }
                    }
                }
                null
            } catch (e: Exception) {
                null
            }
        }
        
        private fun getTotalMemory(): Double? {
            return try {
                val reader = BufferedReader(FileReader("/proc/meminfo"))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    if (line!!.startsWith("MemTotal:")) {
                        val kb = Regex("MemTotal:\\s+(\\d+)").find(line!!)?.groupValues?.get(1)?.toDoubleOrNull()
                        reader.close()
                        return if (kb != null) kb / 1024.0 else null // 转换为 MB
                    }
                }
                reader.close()
                null
            } catch (e: Exception) {
                null
            }
        }
        
        private fun getUsedMemory(): Double {
            return try {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val mi = ActivityManager.MemoryInfo()
                am.getMemoryInfo(mi)
                (mi.totalMem - mi.availMem) / (1024.0 * 1024.0) // 转换为 MB
            } catch (e: Exception) {
                0.0
            }
        }
        
        private fun getWifiName(): String? {
            return try {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val network = cm.activeNetwork ?: return null
                val caps = cm.getNetworkCapabilities(network) ?: return null
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                    "WiFi"
                } else null
            } catch (e: Exception) {
                null
            }
        }
        
        private fun getWifiIP(): String? {
            return null // 简化实现
        }
        
        private fun getNetworkType(): String? {
            return try {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val network = cm.activeNetwork ?: return null
                val caps = cm.getNetworkCapabilities(network) ?: return null
                
                when {
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WiFi"
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Mobile"
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
                    else -> "Unknown"
                }
            } catch (e: Exception) {
                null
            }
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
