#include "flutter_window.h"

#include <dwmapi.h>
#include <optional>
#include <shellapi.h>
#include <sstream>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"
#include "utils.h"

namespace {

#ifndef DWMWA_CLOAKED
#define DWMWA_CLOAKED 14
#endif

#ifndef WS_EX_NOREDIRECTIONBITMAP
#define WS_EX_NOREDIRECTIONBITMAP 0x00200000L
#endif

#ifndef EVENT_OBJECT_CLOAKED
#define EVENT_OBJECT_CLOAKED 0x8017
#endif

#ifndef EVENT_OBJECT_UNCLOAKED
#define EVENT_OBJECT_UNCLOAKED 0x8018
#endif

constexpr UINT kTrayIconMessage = WM_APP + 1;
constexpr UINT kDesktopReattachMessage = WM_APP + 2;
constexpr UINT kTrayOpenSettings = 1001;
constexpr UINT kTrayExit = 1002;
constexpr UINT kProgmanCreateWorkerMessage = 0x052C;
constexpr WPARAM kProgmanSpawnWorkerWParam = 0xD;
constexpr UINT_PTR kDesktopReattachTimerId = 1;
constexpr UINT kDesktopReattachDelayMs = 250;
constexpr ULONGLONG kDesktopEventCooldownMs = 1500;
constexpr wchar_t kRunRegistryPath[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kStartupValueName[] = L"HtmlWallpaper";

struct WorkerCandidate {
  HWND hwnd;
  RECT rect;
  bool visible;
  DWORD cloaked;
  bool has_shell_view;
};

struct WorkerSearchState {
  HWND worker_after_shell = nullptr;
  HWND shell_host = nullptr;
  std::vector<WorkerCandidate> workers;
};

FlutterWindow* g_flutter_window_instance = nullptr;

std::string LastErrorMessage(const char* context) {
  const DWORD error = GetLastError();
  if (error == ERROR_SUCCESS) {
    return std::string(context);
  }

  return std::string(context) + " (Win32 error " + std::to_string(error) + ")";
}

std::wstring QuotedExecutablePath() {
  std::wstring path(MAX_PATH, L'\0');
  const DWORD length =
      GetModuleFileName(nullptr, path.data(), static_cast<DWORD>(path.size()));
  path.resize(length);
  return L"\"" + path + L"\"";
}

std::string HandleToString(HWND hwnd) {
  std::ostringstream stream;
  stream << "0x" << std::hex << reinterpret_cast<uintptr_t>(hwnd);
  return stream.str();
}

std::string RectToString(const RECT& rect) {
  std::ostringstream stream;
  stream << '[' << rect.left << ',' << rect.top << " - " << rect.right << ','
         << rect.bottom << ']';
  return stream.str();
}

std::string WindowStateSummary(HWND hwnd) {
  RECT rect{};
  GetWindowRect(hwnd, &rect);

  DWORD cloaked = 0;
  DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));

  std::ostringstream stream;
  stream << "hwnd=" << HandleToString(hwnd)
         << " visible=" << (IsWindowVisible(hwnd) ? "true" : "false")
         << " cloaked=" << cloaked
         << " rect=" << RectToString(rect);
  return stream.str();
}

long long RectArea(const RECT& rect) {
  const long long width = std::max<LONG>(0, rect.right - rect.left);
  const long long height = std::max<LONG>(0, rect.bottom - rect.top);
  return width * height;
}

void ApplyLayeredOpacity(HWND hwnd, BYTE alpha) {
  SetWindowLongPtr(hwnd, GWL_EXSTYLE,
                   GetWindowLongPtr(hwnd, GWL_EXSTYLE) | WS_EX_LAYERED);
  SetLayeredWindowAttributes(hwnd, 0, alpha, LWA_ALPHA);
}

void CALLBACK DesktopHostEventProc(HWINEVENTHOOK hook,
                                   DWORD event,
                                   HWND hwnd,
                                   LONG id_object,
                                   LONG id_child,
                                   DWORD event_thread,
                                   DWORD event_time) {
  if (event != EVENT_OBJECT_DESTROY || hwnd == nullptr ||
      g_flutter_window_instance == nullptr) {
    return;
  }

  auto* window = g_flutter_window_instance;
  if (!window->GetHandle()) {
    return;
  }

  PostMessage(window->GetHandle(), kDesktopReattachMessage,
              reinterpret_cast<WPARAM>(hwnd), static_cast<LPARAM>(event));
}

BOOL CALLBACK FindWorkerWCallback(HWND window, LPARAM data) {
  auto* state = reinterpret_cast<WorkerSearchState*>(data);
  HWND shell_dll_def_view =
      FindWindowEx(window, nullptr, L"SHELLDLL_DefView", nullptr);
  wchar_t class_name[256];
  class_name[0] = L'\0';
  GetClassName(window, class_name, 255);

  if (shell_dll_def_view != nullptr) {
    state->shell_host = window;
  }

  if (wcscmp(class_name, L"WorkerW") == 0) {
    RECT rect{};
    GetWindowRect(window, &rect);
    DWORD cloaked = 0;
    DwmGetWindowAttribute(window, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
    state->workers.push_back(WorkerCandidate{
        window,
        rect,
        IsWindowVisible(window) != FALSE,
        cloaked,
        shell_dll_def_view != nullptr,
    });
  }

  if (shell_dll_def_view != nullptr && state->worker_after_shell == nullptr) {
    state->worker_after_shell = FindWindowEx(nullptr, window, L"WorkerW", nullptr);
  }

  return TRUE;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  LogToConsole("FlutterWindow::OnCreate");
  g_flutter_window_instance = this;
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }

  RegisterPlugins(flutter_controller_->engine());
  RegisterDesktopChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  LogToConsole("Flutter desktop channel registered.");

  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  LogToConsole("FlutterWindow::OnDestroy");
  should_stay_attached_ = false;
  KillTimer(GetHandle(), kDesktopReattachTimerId);
  UnregisterDesktopHostHook();
  RemoveTrayIcon();
  if (IsAttachedToDesktop()) {
    last_detach_reason_ = "window destroy";
    DetachFromDesktop(false);
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
  if (g_flutter_window_instance == this) {
    g_flutter_window_instance = nullptr;
  }
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_ERASEBKGND:
      if (debug_wallpaper_mode_) {
        RECT rect;
        GetClientRect(hwnd, &rect);
        FillRect(reinterpret_cast<HDC>(wparam), &rect, DebugBackgroundBrush());
        return 1;
      }
      break;
    case WM_PAINT:
      if (debug_wallpaper_mode_) {
        PAINTSTRUCT paint{};
        HDC dc = BeginPaint(hwnd, &paint);
        FillRect(dc, &paint.rcPaint, DebugBackgroundBrush());
        EndPaint(hwnd, &paint);
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case kDesktopReattachMessage: {
      const HWND destroyed_window = reinterpret_cast<HWND>(wparam);
      const DWORD event = static_cast<DWORD>(lparam);
      const bool watching_target = watched_desktop_target_ != nullptr &&
                                   destroyed_window == watched_desktop_target_;
      if (should_stay_attached_ && watching_target) {
        if (event == EVENT_OBJECT_CLOAKED || event == EVENT_OBJECT_HIDE) {
          LogToConsole("Desktop host became hidden/cloaked. Scheduling reattach.");
          ScheduleDesktopReattach("desktop host hidden/cloaked");
          return 0;
        }

        if (event == EVENT_OBJECT_UNCLOAKED || event == EVENT_OBJECT_SHOW) {
          LogToConsole("Desktop host became visible. Reattach timer kept as-is.");
          return 0;
        }

        const ULONGLONG now = GetTickCount64();
        if (reattach_in_progress_ ||
            (last_attach_tick_ != 0 &&
             now - last_attach_tick_ < kDesktopEventCooldownMs)) {
          LogToConsole("Ignoring desktop host destroy during cooldown/in-progress.");
          return 0;
        }
        ScheduleDesktopReattach("desktop host destroyed");
      }
      return 0;
    }
    case WM_TIMER:
      if (wparam == kDesktopReattachTimerId) {
        KillTimer(hwnd, kDesktopReattachTimerId);
        AttemptDesktopReattach();
        return 0;
      }
      break;
    case WM_COMMAND:
      switch (LOWORD(wparam)) {
        case kTrayOpenSettings:
          RestoreFromTray();
          return 0;
        case kTrayExit:
          Destroy();
          return 0;
      }
      break;
    case kTrayIconMessage:
      switch (LOWORD(lparam)) {
        case WM_LBUTTONDBLCLK:
          LogToConsole("Tray icon double-click ignored.");
          return 0;
        case WM_RBUTTONUP:
        case WM_CONTEXTMENU:
          ShowTrayMenu();
          return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RegisterDesktopChannel() {
  desktop_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "html_wallpaper/desktop",
          &flutter::StandardMethodCodec::GetInstance());

  desktop_channel_->SetMethodCallHandler(
      [this](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        if (call.method_name() == "attachToDesktop") {
          LogToConsole("MethodChannel: attachToDesktop");
          result->Success(flutter::EncodableValue(AttachToDesktop()));
          return;
        }
        if (call.method_name() == "detachFromDesktop") {
          LogToConsole("MethodChannel: detachFromDesktop");
          last_detach_reason_ = "flutter method channel";
          should_stay_attached_ = false;
          result->Success(flutter::EncodableValue(DetachFromDesktop(true)));
          return;
        }
        if (call.method_name() == "isAttached") {
          result->Success(flutter::EncodableValue(IsAttachedToDesktop()));
          return;
        }
        if (call.method_name() == "getDesktopStatus") {
          result->Success(flutter::EncodableValue(last_attach_status_));
          return;
        }
        if (call.method_name() == "getLaunchAtStartup") {
          result->Success(flutter::EncodableValue(GetLaunchAtStartup()));
          return;
        }
        if (call.method_name() == "setLaunchAtStartup") {
          const auto* enabled =
              std::get_if<bool>(call.arguments());
          if (enabled == nullptr) {
            result->Error("invalid_args",
                          "setLaunchAtStartup expects a boolean argument.");
            return;
          }
          result->Success(flutter::EncodableValue(
              SetLaunchAtStartup(*enabled)));
          return;
        }

        result->NotImplemented();
      });
}

bool FlutterWindow::AttachToDesktop() {
  return AttachToDesktopInternal(false);
}

bool FlutterWindow::AttachToDesktopInternal(bool reattach_in_place) {
  LogToConsole("AttachToDesktop called.");
  should_stay_attached_ = true;
  if (!reattach_in_place && IsAttachedToDesktop()) {
    SetAttachStatus("Already attached to desktop layer.");
    LogToConsole(last_attach_status_);
    return true;
  }

  progman_ = FindWindow(L"Progman", nullptr);
  shell_dll_def_view_ =
      progman_ == nullptr
          ? nullptr
          : FindWindowEx(progman_, nullptr, L"SHELLDLL_DefView", nullptr);
  const LONG_PTR progman_ex_style =
      progman_ == nullptr ? 0 : GetWindowLongPtr(progman_, GWL_EXSTYLE);
  raised_desktop_mode_ =
      progman_ != nullptr && shell_dll_def_view_ != nullptr &&
      (progman_ex_style & WS_EX_NOREDIRECTIONBITMAP) != 0;

  if (raised_desktop_mode_) {
    LogToConsole("Raised desktop with layered ShellView detected.");
    workerw_ = FindWindowEx(progman_, nullptr, L"WorkerW", nullptr);
    if (workerw_ == nullptr) {
      SetAttachStatus("Raised desktop detected, but Progman child WorkerW is missing.");
      LogToConsole(last_attach_status_);
      return false;
    }
  }

  HWND worker = raised_desktop_mode_ ? progman_ : FindDesktopWorkerW();
  if (worker == nullptr) {
    SetAttachStatus(raised_desktop_mode_
                        ? "Raised desktop detected, but desktop host setup failed."
                        : "Failed to find usable WorkerW.");
    LogToConsole(last_attach_status_);
    return false;
  }
  LogToConsole("Desktop host found: " + HandleToString(worker));
  LogToConsole("Desktop host state before show: " + WindowStateSummary(worker));
  const bool use_progman_fallback = raised_desktop_mode_;
  attached_to_progman_fallback_ = use_progman_fallback;

  saved_style_ = GetWindowLongPtr(GetHandle(), GWL_STYLE);
  saved_ex_style_ = GetWindowLongPtr(GetHandle(), GWL_EXSTYLE);
  saved_parent_ = GetParent(GetHandle());
  LogToConsole("Current window: " + HandleToString(GetHandle()));
  LogToConsole("Current window state before attach: " +
               WindowStateSummary(GetHandle()));

  if (!reattach_in_place) {
    restored_placement_.length = sizeof(WINDOWPLACEMENT);
    GetWindowPlacement(GetHandle(), &restored_placement_);
    GetWindowRect(GetHandle(), &restored_rect_);
  }

  const LONG_PTR current_style = GetWindowLongPtr(GetHandle(), GWL_STYLE);
  const LONG_PTR current_ex_style = GetWindowLongPtr(GetHandle(), GWL_EXSTYLE);
  const LONG_PTR wallpaper_style =
      (current_style & ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX |
                         WS_MAXIMIZEBOX | WS_SYSMENU | WS_POPUP)) |
      WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN | WS_CLIPSIBLINGS;
  LONG_PTR wallpaper_ex_style =
      (current_ex_style & ~(WS_EX_APPWINDOW | WS_EX_WINDOWEDGE)) |
      WS_EX_TOOLWINDOW;
  if (raised_desktop_mode_) {
    wallpaper_ex_style |= WS_EX_LAYERED;
  }

  if (!reattach_in_place) {
    saved_style_ = GetWindowLongPtr(GetHandle(), GWL_STYLE);
    saved_ex_style_ = GetWindowLongPtr(GetHandle(), GWL_EXSTYLE);
    saved_parent_ = GetParent(GetHandle());
  }

  SetWindowLongPtr(GetHandle(), GWL_STYLE, wallpaper_style);
  SetWindowLongPtr(GetHandle(), GWL_EXSTYLE, wallpaper_ex_style);

  SetLastError(ERROR_SUCCESS);
  HWND parent_result = SetParent(GetHandle(), worker);
  if (parent_result == nullptr && GetLastError() != ERROR_SUCCESS) {
    SetAttachStatus(LastErrorMessage("SetParent failed"));
    LogToConsole(last_attach_status_);
    return false;
  }
  LogToConsole("SetParent succeeded. Previous parent: " +
               HandleToString(parent_result));

  const int x = GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int y = GetSystemMetrics(SM_YVIRTUALSCREEN);
  const int width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
  const int height = GetSystemMetrics(SM_CYVIRTUALSCREEN);

  const HWND z_order_target = use_progman_fallback ? HWND_BOTTOM : HWND_TOP;
  if (!SetWindowPos(GetHandle(), z_order_target, x, y, width, height,
                    SWP_NOACTIVATE | SWP_SHOWWINDOW | SWP_FRAMECHANGED)) {
    SetAttachStatus(LastErrorMessage("SetWindowPos failed"));
    LogToConsole(last_attach_status_);
    return false;
  }

  if (raised_desktop_mode_) {
    ApplyLayeredOpacity(GetHandle(), 255);
    const UINT shell_flags =
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW;
    SetWindowPos(GetHandle(), shell_dll_def_view_, 0, 0, 0, 0, shell_flags);
    if (workerw_ != nullptr) {
      SetWindowPos(workerw_, HWND_BOTTOM, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
      LogToConsole("Raised desktop WorkerW child=" + HandleToString(workerw_));
    }
  }

  ShowWindow(worker, SW_SHOWNA);
  UpdateWindow(worker);
  ShowWindow(GetHandle(), SW_SHOWNA);
  UpdateWindow(GetHandle());
  debug_wallpaper_mode_ = false;
  InvalidateRect(GetHandle(), nullptr, TRUE);
  RedrawWindow(GetHandle(), nullptr, nullptr,
               RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW);
  LogToConsole("Desktop host state after show: " + WindowStateSummary(worker));
  LogToConsole("Current window state after attach: " +
               WindowStateSummary(GetHandle()));

  if (!raised_desktop_mode_) {
    workerw_ = worker;
  }
  watched_desktop_target_ = raised_desktop_mode_ ? workerw_ : worker;
  RegisterDesktopHostHook();
  CreateTrayIcon();
  flutter_controller_->ForceRedraw();
  reattach_pending_ = false;
  reattach_in_progress_ = false;
  reattach_attempts_ = 0;
  last_attach_tick_ = GetTickCount64();
  SetAttachStatus(raised_desktop_mode_
                      ? "Attached using layered Progman/SHELLDLL_DefView mode."
                      : "Attached to WorkerW.");
  LogToConsole(last_attach_status_);
  return true;
}

bool FlutterWindow::DetachFromDesktop(bool bring_to_front) {
  LogToConsole(std::string("DetachFromDesktop called. bring_to_front=") +
               (bring_to_front ? "true" : "false") +
               ", reason=" + last_detach_reason_);
  if (!IsAttachedToDesktop()) {
    SetAttachStatus("Already detached from desktop layer.");
    LogToConsole(last_attach_status_);
    return true;
  }

  KillTimer(GetHandle(), kDesktopReattachTimerId);
  UnregisterDesktopHostHook();
  SetParent(GetHandle(), saved_parent_);
  SetWindowLongPtr(GetHandle(), GWL_STYLE, saved_style_);
  SetWindowLongPtr(GetHandle(), GWL_EXSTYLE, saved_ex_style_);
  debug_wallpaper_mode_ = false;

  const int width = restored_rect_.right - restored_rect_.left;
  const int height = restored_rect_.bottom - restored_rect_.top;
  SetWindowPos(GetHandle(), nullptr, restored_rect_.left, restored_rect_.top,
               width, height, SWP_NOZORDER | SWP_SHOWWINDOW | SWP_FRAMECHANGED);
  SetWindowPlacement(GetHandle(), &restored_placement_);

  workerw_ = nullptr;
  progman_ = nullptr;
  shell_dll_def_view_ = nullptr;
  watched_desktop_target_ = nullptr;
  attached_to_progman_fallback_ = false;
  raised_desktop_mode_ = false;
  reattach_pending_ = false;
  reattach_in_progress_ = false;
  reattach_attempts_ = 0;
  RemoveTrayIcon();
  SetAttachStatus("Detached from desktop layer.");
  LogToConsole(last_attach_status_);

  if (bring_to_front) {
    ShowWindow(GetHandle(), SW_SHOWNORMAL);
    SetForegroundWindow(GetHandle());
    SetFocus(GetHandle());
  }

  return true;
}

bool FlutterWindow::IsAttachedToDesktop() const {
  return workerw_ != nullptr;
}

HWND FlutterWindow::FindDesktopWorkerW() const {
  HWND progman = FindWindow(L"Progman", nullptr);
  if (progman == nullptr) {
    LogToConsole("FindDesktopWorkerW: Progman not found.");
    return nullptr;
  }
  LogToConsole("FindDesktopWorkerW: Progman=" + HandleToString(progman));

  DWORD_PTR unused_result = 0;
  SendMessageTimeout(progman, kProgmanCreateWorkerMessage,
                     kProgmanSpawnWorkerWParam, 0, SMTO_NORMAL, 1000,
                     &unused_result);
  SendMessageTimeout(progman, kProgmanCreateWorkerMessage,
                     kProgmanSpawnWorkerWParam, 1, SMTO_NORMAL, 1000,
                     &unused_result);
  SendMessageTimeout(progman, kProgmanCreateWorkerMessage, 0, 0, SMTO_NORMAL,
                     1000, &unused_result);
  Sleep(100);

  WorkerSearchState worker_search_state;
  EnumWindows(FindWorkerWCallback,
              reinterpret_cast<LPARAM>(&worker_search_state));

  const RECT virtual_rect = {GetSystemMetrics(SM_XVIRTUALSCREEN),
                             GetSystemMetrics(SM_YVIRTUALSCREEN),
                             GetSystemMetrics(SM_XVIRTUALSCREEN) +
                                 GetSystemMetrics(SM_CXVIRTUALSCREEN),
                             GetSystemMetrics(SM_YVIRTUALSCREEN) +
                                 GetSystemMetrics(SM_CYVIRTUALSCREEN)};
  const long long virtual_area = RectArea(virtual_rect);

  for (const auto& worker : worker_search_state.workers) {
    std::ostringstream stream;
    stream << "Worker candidate: hwnd=" << HandleToString(worker.hwnd)
           << " visible=" << (worker.visible ? "true" : "false")
           << " cloaked=" << worker.cloaked
           << " hasShellView=" << (worker.has_shell_view ? "true" : "false")
           << " rect=" << RectToString(worker.rect)
           << " area=" << RectArea(worker.rect);
    LogToConsole(stream.str());
  }

  HWND best_worker = nullptr;
  long long best_area = 0;
  for (const auto& worker : worker_search_state.workers) {
    if (worker.has_shell_view) {
      continue;
    }
    const long long area = RectArea(worker.rect);
    if (worker.cloaked == 0 && area > best_area &&
        area >= virtual_area / 2) {
      best_worker = worker.hwnd;
      best_area = area;
    }
  }

  if (best_worker != nullptr) {
    LogToConsole("FindDesktopWorkerW: selected fullscreen WorkerW=" +
                 HandleToString(best_worker));
    return best_worker;
  }

  if (worker_search_state.worker_after_shell != nullptr) {
    LogToConsole("FindDesktopWorkerW: WorkerW after SHELLDLL_DefView=" +
                 HandleToString(worker_search_state.worker_after_shell));
    return worker_search_state.worker_after_shell;
  }

  LogToConsole(
      "FindDesktopWorkerW: no fullscreen WorkerW found; Progman fallback "
      "disabled on this system.");
  return nullptr;
}

void FlutterWindow::SetAttachStatus(const std::string& status) {
  last_attach_status_ = status;
}

void FlutterWindow::RegisterDesktopHostHook() {
  UnregisterDesktopHostHook();
  if (watched_desktop_target_ == nullptr) {
    return;
  }

  desktop_destroy_event_hook_ = SetWinEventHook(
      EVENT_OBJECT_DESTROY, EVENT_OBJECT_DESTROY, nullptr,
      DesktopHostEventProc, 0, 0,
      WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
  desktop_visibility_event_hook_ = SetWinEventHook(
      EVENT_OBJECT_SHOW, EVENT_OBJECT_HIDE, nullptr, DesktopHostEventProc, 0, 0,
      WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
  desktop_cloak_event_hook_ = SetWinEventHook(
      EVENT_OBJECT_CLOAKED, EVENT_OBJECT_UNCLOAKED, nullptr,
      DesktopHostEventProc, 0, 0,
      WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
  const bool success = desktop_destroy_event_hook_ != nullptr &&
                       desktop_visibility_event_hook_ != nullptr &&
                       desktop_cloak_event_hook_ != nullptr;
  LogToConsole(std::string("Desktop host hooks ") +
               (success ? "registered for " : "partially failed for ") +
               HandleToString(watched_desktop_target_));
}

void FlutterWindow::UnregisterDesktopHostHook() {
  if (desktop_destroy_event_hook_ != nullptr) {
    UnhookWinEvent(desktop_destroy_event_hook_);
    desktop_destroy_event_hook_ = nullptr;
  }
  if (desktop_visibility_event_hook_ != nullptr) {
    UnhookWinEvent(desktop_visibility_event_hook_);
    desktop_visibility_event_hook_ = nullptr;
  }
  if (desktop_cloak_event_hook_ != nullptr) {
    UnhookWinEvent(desktop_cloak_event_hook_);
    desktop_cloak_event_hook_ = nullptr;
  }
  LogToConsole("Desktop host hooks removed.");
}

void FlutterWindow::ScheduleDesktopReattach(const std::string& reason) {
  if (!should_stay_attached_) {
    return;
  }
  if (reattach_pending_) {
    KillTimer(GetHandle(), kDesktopReattachTimerId);
    LogToConsole("Desktop reattach rescheduled: " + reason);
  } else {
    reattach_pending_ = true;
    last_attach_status_ = "Desktop host changed, waiting to reattach.";
    LogToConsole("Scheduling desktop reattach: " + reason);
  }
  SetTimer(GetHandle(), kDesktopReattachTimerId, kDesktopReattachDelayMs, nullptr);
}

void FlutterWindow::AttemptDesktopReattach() {
  if (!should_stay_attached_) {
    reattach_pending_ = false;
    reattach_in_progress_ = false;
    return;
  }

  LogToConsole("Attempting desktop reattach #" +
               std::to_string(reattach_attempts_ + 1));
  reattach_in_progress_ = true;
  UnregisterDesktopHostHook();

  const DWORD cloaked = GetWindowCloakedState(GetHandle());
  if (cloaked != 0) {
    reattach_attempts_++;
    LogToConsole("Desktop reattach delayed because wallpaper window is cloaked=" +
                 std::to_string(cloaked));
    if (reattach_attempts_ < 10) {
      SetTimer(GetHandle(), kDesktopReattachTimerId, kDesktopReattachDelayMs,
               nullptr);
    } else {
      LogToConsole("Desktop reattach aborted after repeated cloaked retries.");
      reattach_pending_ = false;
      reattach_in_progress_ = false;
    }
    return;
  }

  const bool attached = AttachToDesktopInternal(true);
  if (attached) {
    LogToConsole("Desktop reattach succeeded.");
    reattach_pending_ = false;
    reattach_in_progress_ = false;
    reattach_attempts_ = 0;
    return;
  }

  reattach_attempts_++;
  if (reattach_attempts_ < 10) {
    LogToConsole("Desktop reattach failed, retrying...");
    SetTimer(GetHandle(), kDesktopReattachTimerId, kDesktopReattachDelayMs,
             nullptr);
  } else {
    LogToConsole("Desktop reattach aborted after repeated failures.");
    reattach_pending_ = false;
    reattach_in_progress_ = false;
  }
}

DWORD FlutterWindow::GetWindowCloakedState(HWND hwnd) const {
  DWORD cloaked = 0;
  DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
  return cloaked;
}

bool FlutterWindow::GetLaunchAtStartup() const {
  HKEY run_key = nullptr;
  const LONG open_result =
      RegOpenKeyEx(HKEY_CURRENT_USER, kRunRegistryPath, 0, KEY_READ, &run_key);
  if (open_result != ERROR_SUCCESS) {
    return false;
  }

  DWORD type = 0;
  DWORD size = 0;
  const LONG query_result = RegQueryValueEx(
      run_key, kStartupValueName, nullptr, &type, nullptr, &size);
  RegCloseKey(run_key);
  return query_result == ERROR_SUCCESS && type == REG_SZ && size > sizeof(wchar_t);
}

bool FlutterWindow::SetLaunchAtStartup(bool enabled) const {
  HKEY run_key = nullptr;
  const LONG create_result = RegCreateKeyEx(
      HKEY_CURRENT_USER, kRunRegistryPath, 0, nullptr, 0,
      KEY_SET_VALUE | KEY_QUERY_VALUE, nullptr, &run_key, nullptr);
  if (create_result != ERROR_SUCCESS) {
    LogToConsole("SetLaunchAtStartup: failed to open Run registry key.");
    return false;
  }

  bool success = false;
  if (enabled) {
    const std::wstring command = QuotedExecutablePath();
    const LONG set_result = RegSetValueEx(
        run_key, kStartupValueName, 0, REG_SZ,
        reinterpret_cast<const BYTE*>(command.c_str()),
        static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
    success = set_result == ERROR_SUCCESS;
  } else {
    const LONG delete_result =
        RegDeleteValue(run_key, kStartupValueName);
    success = delete_result == ERROR_SUCCESS || delete_result == ERROR_FILE_NOT_FOUND;
  }

  RegCloseKey(run_key);
  LogToConsole(std::string("SetLaunchAtStartup: ") +
               (success ? "success" : "failed"));
  return success ? GetLaunchAtStartup() == enabled : false;
}

void FlutterWindow::CreateTrayIcon() {
  if (tray_icon_created_) {
    return;
  }

  NOTIFYICONDATA tray_icon{};
  tray_icon.cbSize = sizeof(NOTIFYICONDATA);
  tray_icon.hWnd = GetHandle();
  tray_icon.uID = 1;
  tray_icon.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  tray_icon.uCallbackMessage = kTrayIconMessage;
  tray_icon.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(tray_icon.szTip, L"HTML Wallpaper");

  tray_icon_created_ = Shell_NotifyIcon(NIM_ADD, &tray_icon) == TRUE;
  LogToConsole(std::string("Tray icon create ") +
               (tray_icon_created_ ? "succeeded." : "failed."));
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_icon_created_) {
    return;
  }

  NOTIFYICONDATA tray_icon{};
  tray_icon.cbSize = sizeof(NOTIFYICONDATA);
  tray_icon.hWnd = GetHandle();
  tray_icon.uID = 1;
  Shell_NotifyIcon(NIM_DELETE, &tray_icon);
  tray_icon_created_ = false;
  LogToConsole("Tray icon removed.");
}

void FlutterWindow::ShowTrayMenu() {
  HMENU menu = CreatePopupMenu();
  if (menu == nullptr) {
    return;
  }

  AppendMenu(menu, MF_STRING, kTrayOpenSettings, L"Open settings");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, kTrayExit, L"Exit");

  POINT cursor_pos{};
  GetCursorPos(&cursor_pos);
  SetForegroundWindow(GetHandle());
  TrackPopupMenu(menu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, cursor_pos.x,
                 cursor_pos.y, 0, GetHandle(), nullptr);
  DestroyMenu(menu);
}

void FlutterWindow::RestoreFromTray() {
  LogToConsole("RestoreFromTray");
  last_detach_reason_ = "tray restore";
  should_stay_attached_ = false;
  DetachFromDesktop(true);
}

HBRUSH FlutterWindow::DebugBackgroundBrush() const {
  static HBRUSH brush = CreateSolidBrush(RGB(0, 255, 120));
  return brush;
}
