#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Absolute UTF-8 paths of the existing files named on the command line.
// Explorer runs `svga_gallery.exe "%1"` for "Open with" and double-click.
std::vector<std::string> FilesFromCommandLine() {
  std::vector<std::string> files;
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return files;
  }
  for (int i = 1; i < argc; i++) {
    DWORD size = ::GetFullPathNameW(argv[i], 0, nullptr, nullptr);
    if (size == 0) continue;
    std::wstring full(size, L'\0');
    DWORD length = ::GetFullPathNameW(argv[i], size, full.data(), nullptr);
    if (length == 0 || length >= size) continue;
    full.resize(length);
    DWORD attributes = ::GetFileAttributesW(full.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES ||
        (attributes & FILE_ATTRIBUTE_DIRECTORY)) {
      continue;
    }
    files.push_back(Utf8FromUtf16(full.c_str()));
  }
  ::LocalFree(argv);
  return files;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::vector<std::string> opened_files = FilesFromCommandLine();

  // One instance per user session: opening a file while the app runs hands
  // it to the running window, so two copies never rewrite the library index
  // at once. The handle stays open until the process exits.
  ::CreateMutexW(nullptr, FALSE, L"Local\\com.silifton.svga_gallery");
  if (::GetLastError() == ERROR_ALREADY_EXISTS &&
      ForwardToRunningInstance(opened_files)) {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, std::move(opened_files));
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kMainWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
