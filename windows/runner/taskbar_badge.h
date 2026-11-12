#ifndef RUNNER_TASKBAR_BADGE_H_
#define RUNNER_TASKBAR_BADGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shobjidl.h>

#include <memory>
#include <string>

class TaskbarBadge {
 public:
  static void RegisterWithMessenger(flutter::BinaryMessenger* messenger, HWND window_handle);

  TaskbarBadge(HWND window_handle);
  ~TaskbarBadge();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void EnsureTaskbarList();
  void SetOverlayBadge(int count, int r, int g, int b);
  void ClearOverlayBadge();
  HICON CreateBadgeIcon(int count, COLORREF bg_color);

  HWND window_handle_;
  ITaskbarList3* taskbar_list_;
  HICON current_icon_;
};

#endif  // RUNNER_TASKBAR_BADGE_H_

