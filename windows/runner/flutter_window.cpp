#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// WM_COPYDATA tag for "open these files"; the payload is UTF-8 paths joined
// by '\n' (a character Windows paths cannot contain).
constexpr ULONG_PTR kOpenFilesMessage = 0x53564741;  // "SVGA"

// Class name registered by Win32Window (win32_window.cpp).
constexpr wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

std::vector<std::string> SplitLines(const std::string& text) {
  std::vector<std::string> lines;
  size_t start = 0;
  while (start <= text.size()) {
    size_t end = text.find('\n', start);
    if (end == std::string::npos) end = text.size();
    if (end > start) lines.push_back(text.substr(start, end - start));
    start = end + 1;
  }
  return lines;
}

}  // namespace

bool ForwardToRunningInstance(const std::vector<std::string>& files) {
  // The first instance creates its window shortly after it starts.
  HWND window = nullptr;
  for (int attempt = 0; attempt < 50 && window == nullptr; attempt++) {
    window = ::FindWindowW(kWindowClassName, kMainWindowTitle);
    if (window == nullptr) ::Sleep(100);
  }
  if (window == nullptr) return false;

  std::string payload;
  for (const auto& file : files) {
    if (!payload.empty()) payload += '\n';
    payload += file;
  }
  COPYDATASTRUCT data;
  data.dwData = kOpenFilesMessage;
  data.cbData = static_cast<DWORD>(payload.size());
  data.lpData = payload.empty() ? nullptr : payload.data();
  DWORD_PTR reply = 0;
  if (!::SendMessageTimeoutW(window, WM_COPYDATA, 0,
                             reinterpret_cast<LPARAM>(&data), SMTO_ABORTIFHUNG,
                             5000, &reply)) {
    return false;
  }

  // This process was just started by the user, so it may hand the
  // foreground to the other one.
  if (::IsIconic(window)) ::ShowWindow(window, SW_RESTORE);
  ::SetForegroundWindow(window);
  return true;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             std::vector<std::string> opened_files)
    : project_(project), pending_files_(std::move(opened_files)) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  open_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "svga_gallery/open",
          &flutter::StandardMethodCodec::GetInstance());
  open_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "takePending") {
          result->NotImplemented();
          return;
        }
        dart_listening_ = true;
        flutter::EncodableList files;
        for (const auto& file : pending_files_) files.emplace_back(file);
        pending_files_.clear();
        result->Success(flutter::EncodableValue(std::move(files)));
      });

  // Accept forwarded files even if this instance runs elevated.
  ::ChangeWindowMessageFilterEx(GetHandle(), WM_COPYDATA, MSGFLT_ALLOW,
                                nullptr);

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  open_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::OpenFiles(std::vector<std::string> files) {
  if (files.empty()) return;
  if (!dart_listening_ || !open_channel_) {
    pending_files_.insert(pending_files_.end(), files.begin(), files.end());
    return;
  }
  flutter::EncodableList list;
  for (auto& file : files) list.emplace_back(std::move(file));
  open_channel_->InvokeMethod(
      "open", std::make_unique<flutter::EncodableValue>(std::move(list)));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Files forwarded by a second instance (see ForwardToRunningInstance).
  if (message == WM_COPYDATA) {
    const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
    if (data != nullptr && data->dwData == kOpenFilesMessage) {
      if (data->lpData != nullptr && data->cbData > 0) {
        OpenFiles(SplitLines(std::string(
            static_cast<const char*>(data->lpData), data->cbData)));
      }
      return TRUE;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
