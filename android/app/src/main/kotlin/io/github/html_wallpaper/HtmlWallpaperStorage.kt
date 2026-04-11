package io.github.html_wallpaper

import android.content.Context
import java.io.File

data class HtmlWallpaperSpec(
    val html: String,
    val baseUrl: String?,
    val version: Long,
)

object HtmlWallpaperStorage {
    private const val preferencesName = "html_wallpaper_preferences"
    private const val baseUrlKey = "android.wallpaper.base_url"
    private const val versionKey = "android.wallpaper.version"
    private const val htmlDirectoryName = "wallpaper"
    private const val htmlFileName = "current_wallpaper.html"

    private const val fallbackHtml = """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1.0" />
            <style>
              html, body {
                width: 100%;
                height: 100%;
                margin: 0;
                overflow: hidden;
                background: radial-gradient(circle at top, #28354a, #0a0f17 72%);
                color: white;
                font-family: sans-serif;
              }
              body {
                display: grid;
                place-items: center;
              }
              .card {
                padding: 24px 28px;
                border: 1px solid rgba(255, 255, 255, 0.16);
                border-radius: 24px;
                background: rgba(9, 16, 24, 0.82);
                box-shadow: 0 20px 50px rgba(0, 0, 0, 0.28);
              }
            </style>
          </head>
          <body>
            <div class="card">在应用中选择一个 HTML 后，再把它设为安卓动态壁纸。</div>
          </body>
        </html>
    """

    fun save(context: Context, html: String, baseUrl: String?): Boolean {
        return try {
            val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            val currentVersion = preferences.getLong(versionKey, 0L)
            val now = System.currentTimeMillis()
            val version = if (now > currentVersion) now else currentVersion + 1L
            wallpaperFile(context).apply {
                parentFile?.mkdirs()
                writeText(html, Charsets.UTF_8)
            }

            preferences.edit()
                .putString(baseUrlKey, baseUrl)
                .putLong(versionKey, version)
                .commit()
        } catch (_: Exception) {
            false
        }
    }

    fun load(context: Context): HtmlWallpaperSpec {
        val html = try {
            wallpaperFile(context).takeIf(File::exists)?.readText(Charsets.UTF_8)
        } catch (_: Exception) {
            null
        }

        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val baseUrl = preferences.getString(baseUrlKey, null)
        val version = preferences.getLong(
            versionKey,
            wallpaperFile(context).takeIf(File::exists)?.lastModified() ?: 0L,
        )

        return HtmlWallpaperSpec(
            html = html?.takeIf(String::isNotBlank) ?: fallbackHtml,
            baseUrl = baseUrl,
            version = version,
        )
    }

    private fun wallpaperFile(context: Context): File {
        return File(File(context.filesDir, htmlDirectoryName), htmlFileName)
    }
}
