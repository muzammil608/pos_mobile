#include "flutter_window.h"

#include <optional>
#include <windows.h>
#include <tlhelp32.h>

#include "flutter/generated_plugin_registrant.h"

static void TerminateProcessByName(const wchar_t* processName) {
  HANDLE snapshot = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) {
    return;
  }

  PROCESSENTRY32W processEntry;
  processEntry.dwSize = sizeof(processEntry);

  if (::Process32FirstW(snapshot, &processEntry)) {
    do {
      if (_wcsicmp(processEntry.szExeFile, processName) == 0) {
        HANDLE hProcess = ::OpenProcess(PROCESS_TERMINATE, FALSE, processEntry.th32ProcessID);
        if (hProcess != NULL) {
          ::TerminateProcess(hProcess, 0);
          ::CloseHandle(hProcess);
        }
      }
    } while (::Process32NextW(snapshot, &processEntry));
  }
  ::CloseHandle(snapshot);
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

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
  // Ensure background PocketBase process is terminated silently when window is closed
  TerminateProcessByName(L"pocketbase.exe");

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
