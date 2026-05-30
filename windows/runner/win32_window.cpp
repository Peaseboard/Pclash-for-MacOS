#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

/// Window attribute that is used to disable composition for the window.
/// This is used to disable the Aero glass effect for this window.
constexpr DWORD kDwmBlurBehind = 0x00000002;

/// Window attribute that is used to disable the window shadow.
constexpr DWORD kDwmNcRenderingPolicy = 0x00000003;

/// Window attribute that is used to set the non-client rendering policy.
constexpr DWORD kDwmNcRenderingDisabled = 0x00000000;

}  // namespace

Win32Window::Win32Window() = default;

Win32Window::~Win32Window() {
  if (hwnd_) {
    ::DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }
}

bool Win32Window::Create(const std::wstring& title, const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class_name = kWindowClassName;

  // Register the window class.
  WNDCLASS window_class = {};
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.lpfnWndProc = DefWindowProc;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.hIcon =
      LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.hbrBackground = 0;
  window_class.lpszClassName = window_class_name;
  ::RegisterClass(&window_class);

  // Create the window.
  hwnd_ = ::CreateWindowEx(
      0,                              // Optional styles.
      window_class_name,              // Window class name.
      title.c_str(),                  // Window title.
      WS_OVERLAPPEDWINDOW,            // Window style.
      CW_USEDEFAULT, CW_USEDEFAULT,   // Default position.
      CW_USEDEFAULT, CW_USEDEFAULT,   // Default size.
      nullptr,                        // Parent window.
      nullptr,                        // Menu.
      window_class.hInstance,         // Instance handle.
      nullptr                         // Additional application data.
  );
  if (!hwnd_) {
    return false;
  }

  // Force the window to be shown in the taskbar.
  ::SetWindowLongPtr(hwnd_, GWLP_HWNDPARENT, 0);

  // Center the window.
  RECT window_rect = {0, 0, static_cast<LONG>(size.width),
                      static_cast<LONG>(size.height)};
  ::AdjustWindowRectEx(&window_rect, WS_OVERLAPPEDWINDOW, FALSE, 0);
  ::SetWindowPos(hwnd_, HWND_TOP,
                 origin.x, origin.y,
                 window_rect.right - window_rect.left,
                 window_rect.bottom - window_rect.top,
                 SWP_NOZORDER | SWP_NOACTIVATE);

  ::ShowWindow(hwnd_, SW_SHOWNA);

  return true;
}

bool Win32Window::Show() {
  return ::ShowWindow(hwnd_, SW_SHOWNORMAL);
}

void Win32Window::Destroy() {
  if (hwnd_) {
    ::DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }
}

void Win32Window::SetChildContent(HWND content) {
  ::SetParent(content, hwnd_);
  ::SetWindowPos(content, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
}

HWND Win32Window::GetHandle() {
  return hwnd_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  ::GetClientRect(hwnd_, &frame);
  return frame;
}

LRESULT Win32Window::MessageHandler(HWND hwnd, UINT const message,
                                    WPARAM const wparam,
                                    LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      hwnd_ = nullptr;
      if (quit_on_close_) {
        ::PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;
      ::SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                     newHeight, SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }

    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        ::MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                     rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        ::SetFocus(child_content_);
      }
      return 0;
  }

  return ::DefWindowProc(hwnd_, message, wparam, lparam);
}
