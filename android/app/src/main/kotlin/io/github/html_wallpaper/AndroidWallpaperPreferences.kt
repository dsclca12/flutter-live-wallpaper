package io.github.html_wallpaper

import android.content.Context

data class AndroidRenderConfig(
    val enabled: Boolean,
    val scale: Float,
)

object AndroidWallpaperPreferences {
    private const val preferencesName = "html_wallpaper_preferences"
    private const val dynamicColorsEnabledKey = "android.wallpaper.dynamic_colors_enabled"
    private const val autoStartOnBootEnabledKey = "android.wallpaper.auto_start_on_boot_enabled"
    private const val renderScaleEnabledKey = "android.wallpaper.render_scale_enabled"
    private const val renderScaleValueKey = "android.wallpaper.render_scale_value"
    private const val defaultRenderScale = 0.5f

    fun isDynamicColorsEnabled(context: Context): Boolean {
        return context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .getBoolean(dynamicColorsEnabledKey, true)
    }

    fun setDynamicColorsEnabled(context: Context, enabled: Boolean): Boolean {
        return context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(dynamicColorsEnabledKey, enabled)
            .commit()
    }

    fun isAutoStartOnBootEnabled(context: Context): Boolean {
        return context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .getBoolean(autoStartOnBootEnabledKey, false)
    }

    fun setAutoStartOnBootEnabled(context: Context, enabled: Boolean): Boolean {
        return context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(autoStartOnBootEnabledKey, enabled)
            .commit()
    }

    fun getRenderConfig(context: Context): AndroidRenderConfig {
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        // 默认开启渲染缩放，以显著降低 RAM 占用（静态壁纸尤为明显）
        val enabled = preferences.getBoolean(renderScaleEnabledKey, true)
        val scale = preferences.getFloat(renderScaleValueKey, defaultRenderScale)
            .coerceIn(0.25f, 1.0f)
        return AndroidRenderConfig(
            enabled = enabled,
            scale = scale,
        )
    }

    fun setRenderConfig(context: Context, enabled: Boolean, scale: Float): Boolean {
        return context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(renderScaleEnabledKey, enabled)
            .putFloat(renderScaleValueKey, scale.coerceIn(0.25f, 1.0f))
            .commit()
    }
}
