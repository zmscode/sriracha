# Sriracha

A cross-platform native GUI framework for Zig with built-in WebView support.

Sriracha provides a unified API for creating windows and embedding web content across macOS, Windows, and Linux — with zero runtime dependencies beyond what the OS provides.

## Platform Backends

| Platform | Window | WebView |
|----------|--------|---------|
| macOS | AppKit | WebKit (WKWebView) |
| Windows | Win32 | WebView2 (Edge) |
| Linux | GTK 3 | WebKitGTK |

## Features

- Native window creation, positioning, resizing, and styling
- WebView with URL/HTML loading, JS evaluation, and JS-to-Zig messaging
- Single executable output (WebView2Loader.dll embedded on Windows)
- Cross-compilation from macOS to Windows via `zig build -Dtarget=x86_64-windows`

## Requirements

- [Zig](https://ziglang.org/) (master/nightly)
- **macOS:** No extra dependencies (AppKit/WebKit are system frameworks)
- **Windows:** Edge WebView2 runtime (pre-installed on Windows 10/11)
- **Linux:** `libgtk-3-dev` and `libwebkit2gtk-4.1-dev`

## Build & Run

```sh
# Build
zig build

# Run the default demo (webview_load_html)
zig build run

# Run a specific demo
zig build run -- webview_load_url

# Cross-compile for Windows
zig build -Dtarget=x86_64-windows

# Release build
zig build -Drelease
```

## Demos

Pass any demo name as a command-line argument:

```sh
zig build run -- <demo_name>
```

**Window lifecycle:** `window_create`, `window_destroy`, `window_close`

**Window properties:** `window_set_title`, `window_set_frame`, `window_min_max_size`, `window_get_frame`

**Window visibility:** `window_show_hide`, `window_miniaturize`, `window_center`

**Window style:** `window_borderless`, `window_set_style_mask`, `window_transparent_titlebar`, `window_title_visibility`

**Window misc:** `window_alpha`, `window_toggle_fullscreen`, `window_traffic_light_pos` (macOS only), `window_order_front_back`, `window_callbacks`

**WebView:** `webview_create_destroy`, `webview_load_url`, `webview_load_html`, `webview_reload`, `webview_back_forward`, `webview_eval_js`, `webview_js_to_zig`, `webview_attach_detach`

## Project Structure

```
src/
  sriracha.zig              # Entry point, demo runner, public API
  platform/
    macos/                  # AppKit + WebKit backend
      app.zig               # NSApplication lifecycle
      window.zig            # NSWindow management
      webview.zig           # WKWebView integration
      objc.zig              # Objective-C runtime bindings
    windows/                # Win32 + WebView2 backend
      app.zig               # Message loop lifecycle
      window.zig            # HWND management
      webview.zig           # WebView2 COM integration
      win32.zig             # Win32 API declarations
      WebView2Loader.dll    # Embedded into exe at compile time
    linux/                  # GTK 3 + WebKitGTK backend
      app.zig               # gtk_main lifecycle
      window.zig            # GtkWindow management
      webview.zig           # WebKitGTK integration
      gtk.zig               # GTK/GLib/WebKit declarations
build.zig
build.zig.zon
```

## License

MIT
