#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void RegisterDesktopChannel();
  bool AttachToDesktop();
  bool DetachFromDesktop(bool bring_to_front);
  bool IsAttachedToDesktop() const;
  HWND FindDesktopWorkerW() const;
  void SetAttachStatus(const std::string& status);
  void RegisterDesktopHostHook();
  void UnregisterDesktopHostHook();
  void ScheduleDesktopReattach(const std::string& reason);
  void AttemptDesktopReattach();
  bool AttachToDesktopInternal(bool reattach_in_place);
  DWORD GetWindowCloakedState(HWND hwnd) const;
  bool GetLaunchAtStartup() const;
  bool SetLaunchAtStartup(bool enabled) const;
  void CreateTrayIcon();
  void RemoveTrayIcon();
  void ShowTrayMenu();
  void RestoreFromTray();
  HBRUSH DebugBackgroundBrush() const;

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      desktop_channel_;

  WINDOWPLACEMENT restored_placement_{sizeof(WINDOWPLACEMENT)};
  RECT restored_rect_{};
  LONG_PTR saved_style_ = 0;
  LONG_PTR saved_ex_style_ = 0;
  HWND saved_parent_ = nullptr;
  HWND workerw_ = nullptr;
  HWND progman_ = nullptr;
  HWND shell_dll_def_view_ = nullptr;
  HWND watched_desktop_target_ = nullptr;
  HWINEVENTHOOK desktop_destroy_event_hook_ = nullptr;
  HWINEVENTHOOK desktop_visibility_event_hook_ = nullptr;
  HWINEVENTHOOK desktop_cloak_event_hook_ = nullptr;
  bool tray_icon_created_ = false;
  bool attached_to_progman_fallback_ = false;
  bool raised_desktop_mode_ = false;
  bool should_stay_attached_ = false;
  bool reattach_pending_ = false;
  bool reattach_in_progress_ = false;
  int reattach_attempts_ = 0;
  ULONGLONG last_attach_tick_ = 0;
  std::string last_attach_status_ = "Not attached yet.";
  std::string last_detach_reason_ = "unknown";
  bool debug_wallpaper_mode_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
