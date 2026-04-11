package io.github.html_wallpaper

import android.app.WallpaperManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (
            action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        // Always request a refresh, so active wallpaper instances pick up latest saved HTML/settings.
        HtmlWallpaperService.requestReload()
        HtmlWallpaperService.requestColorRefresh()
        if (!AndroidWallpaperPreferences.isAutoStartOnBootEnabled(context)) {
            return
        }

        // Only launch the app at boot when our wallpaper service is active.
        if (!isWallpaperActive(context)) {
            return
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("opened_from_boot", true)
        }
        try {
            context.startActivity(launchIntent)
        } catch (_: Exception) {
            // Ignore. Some Android versions/ROMs may block background activity launch.
        }
    }

    private fun isWallpaperActive(context: Context): Boolean {
        val info = WallpaperManager.getInstance(context).wallpaperInfo ?: return false
        val target = ComponentName(context, HtmlWallpaperService::class.java)
        return info.packageName == target.packageName && info.serviceName == target.className
    }
}
