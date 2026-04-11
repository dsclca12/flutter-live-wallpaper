package io.github.html_wallpaper

import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

private const val androidWallpaperChannel = "html_wallpaper/android"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            androidWallpaperChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareWallpaper" -> {
                    val html = call.argument<String>("html")
                    if (html.isNullOrBlank()) {
                        result.error("invalid_html", "HTML content is empty.", null)
                        return@setMethodCallHandler
                    }

                    val baseUrl = call.argument<String>("baseUrl")
                    val saved = HtmlWallpaperStorage.save(this, html, baseUrl)
                    if (saved) {
                        HtmlWallpaperService.requestReload()
                        HtmlWallpaperService.requestColorRefresh()
                    }
                    result.success(saved)
                }

                "openWallpaperPicker" -> {
                    result.success(openWallpaperPicker())
                }

                "isWallpaperActive" -> {
                    result.success(isWallpaperActive())
                }

                "getDynamicColorsEnabled" -> {
                    result.success(AndroidWallpaperPreferences.isDynamicColorsEnabled(this))
                }

                "setDynamicColorsEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled == null) {
                        result.error("invalid_enabled", "enabled is required.", null)
                        return@setMethodCallHandler
                    }
                    val updated = AndroidWallpaperPreferences.setDynamicColorsEnabled(this, enabled)
                    if (updated) {
                        HtmlWallpaperService.requestColorRefresh()
                    }
                    result.success(updated)
                }

                "getAutoStartOnBootEnabled" -> {
                    result.success(AndroidWallpaperPreferences.isAutoStartOnBootEnabled(this))
                }

                "setAutoStartOnBootEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled == null) {
                        result.error("invalid_enabled", "enabled is required.", null)
                        return@setMethodCallHandler
                    }
                    result.success(
                        AndroidWallpaperPreferences.setAutoStartOnBootEnabled(this, enabled),
                    )
                }

                "getRenderConfig" -> {
                    val config = AndroidWallpaperPreferences.getRenderConfig(this)
                    result.success(
                        mapOf(
                            "enabled" to config.enabled,
                            "scale" to config.scale.toDouble(),
                        ),
                    )
                }

                "setRenderConfig" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    val scaleRaw = call.argument<Double>("scale")
                    if (enabled == null || scaleRaw == null) {
                        result.error("invalid_args", "enabled and scale are required.", null)
                        return@setMethodCallHandler
                    }
                    val saved = AndroidWallpaperPreferences.setRenderConfig(
                        this,
                        enabled,
                        scaleRaw.toFloat(),
                    )
                    if (saved) {
                        HtmlWallpaperService.requestRenderConfigReload()
                    }
                    result.success(saved)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun openWallpaperPicker(): Boolean {
        val wallpaperComponent = ComponentName(this, HtmlWallpaperService::class.java)
        val intents = mutableListOf<Intent>()

        if (isMiuiFamilyDevice()) {
            intents += Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER)
            intents += Intent("miui.intent.action.THEME_WALLPAPER_PICKER_PAGE")
                .setPackage("com.android.thememanager")
            intents += Intent("miui.intent.action.WALLPAPER_PICKER_PAGE")
                .setPackage("com.android.thememanager")
            intents += Intent().setClassName(
                "com.android.thememanager",
                "com.android.thememanager.settings.personalize.activity.PersonalizeActivity",
            )
            intents += Intent().setClassName(
                "com.android.thememanager",
                "com.android.thememanager.settings.ThemeAndWallpaperSettingActivity",
            )
        }

        intents += Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
            putExtra(
                WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                wallpaperComponent,
            )
        }
        intents += Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER)

        for (intent in intents) {
            if (startIntentSafely(intent)) {
                return true
            }
        }
        return false
    }

    private fun startIntentSafely(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun isMiuiFamilyDevice(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase(Locale.US)
        val brand = Build.BRAND.lowercase(Locale.US)
        return manufacturer.contains("xiaomi") ||
            manufacturer.contains("redmi") ||
            manufacturer.contains("poco") ||
            brand.contains("xiaomi") ||
            brand.contains("redmi") ||
            brand.contains("poco")
    }

    private fun isWallpaperActive(): Boolean {
        val wallpaperInfo = WallpaperManager.getInstance(this).wallpaperInfo ?: return false
        return wallpaperInfo.packageName == packageName &&
            wallpaperInfo.serviceName == HtmlWallpaperService::class.java.name
    }
}
