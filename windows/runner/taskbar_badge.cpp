#include "taskbar_badge.h"

#include <gdiplus.h>
#include <sstream>

#pragma comment(lib, "gdiplus.lib")

namespace {
ULONG_PTR gdiplusToken = 0;
bool gdiplusInitialized = false;

void EnsureGdiplus() {
  if (!gdiplusInitialized) {
    Gdiplus::GdiplusStartupInput input;
    Gdiplus::GdiplusStartup(&gdiplusToken, &input, NULL);
    gdiplusInitialized = true;
  }
}
}  // namespace

void TaskbarBadge::RegisterWithMessenger(flutter::BinaryMessenger* messenger, HWND window_handle) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "consistency_tracker/taskbar_badge",
      &flutter::StandardMethodCodec::GetInstance());

  auto badge_handler = std::make_shared<TaskbarBadge>(window_handle);

  channel->SetMethodCallHandler(
      [badge_handler](const flutter::MethodCall<flutter::EncodableValue>& call,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        badge_handler->HandleMethodCall(call, std::move(result));
      });
}

TaskbarBadge::TaskbarBadge(HWND window_handle)
    : window_handle_(window_handle), taskbar_list_(nullptr), current_icon_(nullptr) {
  EnsureGdiplus();
  EnsureTaskbarList();
}

TaskbarBadge::~TaskbarBadge() {
  ClearOverlayBadge();
  if (taskbar_list_) {
    taskbar_list_->Release();
    taskbar_list_ = nullptr;
  }
}

void TaskbarBadge::EnsureTaskbarList() {
  if (!taskbar_list_) {
    CoInitialize(NULL);
    HRESULT hr = CoCreateInstance(CLSID_TaskbarList, NULL, CLSCTX_INPROC_SERVER,
                                  IID_ITaskbarList3, (void**)&taskbar_list_);
    if (SUCCEEDED(hr) && taskbar_list_) {
      taskbar_list_->HrInit();
    }
  }
}

void TaskbarBadge::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "setBadge") {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args) {
      int count = 0;
      int r = 239, g = 68, b = 68; // Default Red

      auto it_count = args->find(flutter::EncodableValue("count"));
      if (it_count != args->end() && std::holds_alternative<int>(it_count->second)) {
        count = std::get<int>(it_count->second);
      }

      auto it_r = args->find(flutter::EncodableValue("r"));
      if (it_r != args->end() && std::holds_alternative<int>(it_r->second)) {
        r = std::get<int>(it_r->second);
      }
      auto it_g = args->find(flutter::EncodableValue("g"));
      if (it_g != args->end() && std::holds_alternative<int>(it_g->second)) {
        g = std::get<int>(it_g->second);
      }
      auto it_b = args->find(flutter::EncodableValue("b"));
      if (it_b != args->end() && std::holds_alternative<int>(it_b->second)) {
        b = std::get<int>(it_b->second);
      }

      SetOverlayBadge(count, r, g, b);
      result->Success(flutter::EncodableValue(true));
      return;
    }
    result->Error("INVALID_ARGUMENTS", "Expected map with count, r, g, b");
  } else if (method == "clearBadge") {
    ClearOverlayBadge();
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

void TaskbarBadge::SetOverlayBadge(int count, int r, int g, int b) {
  EnsureTaskbarList();
  if (!taskbar_list_ || !window_handle_) return;

  if (current_icon_) {
    DestroyIcon(current_icon_);
    current_icon_ = nullptr;
  }

  COLORREF bg_color = RGB(r, g, b);
  current_icon_ = CreateBadgeIcon(count, bg_color);

  if (current_icon_) {
    std::wstring desc = std::to_wstring(count) + L" tasks remaining";
    taskbar_list_->SetOverlayIcon(window_handle_, current_icon_, desc.c_str());
  } else {
    taskbar_list_->SetOverlayIcon(window_handle_, NULL, NULL);
  }
}

void TaskbarBadge::ClearOverlayBadge() {
  EnsureTaskbarList();
  if (taskbar_list_ && window_handle_) {
    taskbar_list_->SetOverlayIcon(window_handle_, NULL, NULL);
  }
  if (current_icon_) {
    DestroyIcon(current_icon_);
    current_icon_ = nullptr;
  }
}

HICON TaskbarBadge::CreateBadgeIcon(int count, COLORREF bg_color) {
  int size = GetSystemMetrics(SM_CXSMICON);
  if (size <= 0) size = 16;

  Gdiplus::Bitmap bitmap(size, size, PixelFormat32bppARGB);
  Gdiplus::Graphics graphics(&bitmap);

  graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
  graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);

  // Clear background with transparent
  graphics.Clear(Gdiplus::Color(0, 0, 0, 0));

  // Draw circle badge
  Gdiplus::Color circleColor(255, GetRValue(bg_color), GetGValue(bg_color), GetBValue(bg_color));
  Gdiplus::SolidBrush brush(circleColor);
  graphics.FillEllipse(&brush, 0, 0, size - 1, size - 1);

  // Draw white border around circle for readability against light taskbar
  Gdiplus::Pen borderPen(Gdiplus::Color(200, 255, 255, 255), 1.0f);
  graphics.DrawEllipse(&borderPen, 0, 0, size - 1, size - 1);

  // Draw text
  std::wstring text = std::to_wstring(count);
  if (count > 99) text = L"99+";
  else if (count > 9) text = L"9+";

  Gdiplus::FontFamily fontFamily(L"Segoe UI");
  Gdiplus::REAL fontSize = (Gdiplus::REAL)(size * (count > 9 ? 0.48f : 0.58f));
  Gdiplus::Font font(&fontFamily, fontSize, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
  Gdiplus::SolidBrush textBrush(Gdiplus::Color(255, 255, 255, 255));

  Gdiplus::StringFormat format;
  format.SetAlignment(Gdiplus::StringAlignmentCenter);
  format.SetLineAlignment(Gdiplus::StringAlignmentCenter);

  Gdiplus::RectF rect(0, 0, (Gdiplus::REAL)size, (Gdiplus::REAL)size);
  graphics.DrawString(text.c_str(), -1, &font, rect, &format, &textBrush);

  HICON hIcon = NULL;
  Gdiplus::Status status = bitmap.GetHICON(&hIcon);
  if (status != Gdiplus::Ok) {
    return NULL;
  }
  return hIcon;
}
