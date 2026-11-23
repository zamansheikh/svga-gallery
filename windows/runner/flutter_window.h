#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>
#include <vector>

#include "win32_window.h"

// Title of the main window; a second instance finds the first one by it.
inline constexpr wchar_t kMainWindowTitle[] = L"SVGA Gallery";

// Hands |files| (UTF-8 absolute paths, may be empty) to an instance that is
// already running and brings its window to the front. Returns false when no
// such window turns up within a few seconds.
bool ForwardToRunningInstance(const std::vector<std::string>& files);

// A window that hosts a Flutter view and passes files the app is asked to
// open to Dart over the "svga_gallery/open" channel.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  // |opened_files| are the files named on the command line.
  FlutterWindow(const flutter::DartProject& project,
                std::vector<std::string> opened_files);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Sends |files| to Dart, or queues them until Dart asks ("takePending").
  void OpenFiles(std::vector<std::string> files);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      open_channel_;
  std::vector<std::string> pending_files_;
  bool dart_listening_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
