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
- **macOS:** No extra dependencies
- **Windows:** Edge WebView2 runtime (pre-installed on Windows 10/11)
- **Linux:** `libgtk-3-dev` and `libwebkit2gtk-4.1-dev`

Windows loader note:
- `src/platform/windows/WebView2Loader.dll` is the canonical embedded loader binary.
- Replace that file directly when updating the bundled WebView2 loader version.

## Installation

Fetch the package:

```sh
zig fetch --save git+https://github.com/zmscode/sriracha
```

Then in your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sriracha_dep = b.dependency("sriracha", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "sriracha", .module = sriracha_dep.module("sriracha") },
            },
        }),
    });

    b.installArtifact(exe);
}
```

For local development in this repo, build the demo explicitly:

```sh
zig build -Dbuild_demo=true
zig build run -Dbuild_demo=true
```

## Usage

```zig
const sriracha = @import("sriracha");

var window: sriracha.Window = .{};
var webview: sriracha.WebView = .{};

pub fn main(init: @import("std").process.Init) !void {
    _ = init;

    sriracha.app.init(.{ .on_ready = onReady });

    window.create(.{
        .title = "My App",
        .callbacks = .{ .on_close = onClose },
    });
    window.center();
    window.show();

    webview.create(.{});
    webview.attachToWindow(&window);
    webview.loadHTML(
        \\<html>
        \\<body style="font-family: system-ui; padding: 40px;">
        \\  <h1>Hello from Sriracha</h1>
        \\</body>
        \\</html>
    , null);

    sriracha.app.run();
}

fn onReady() void {}

fn onClose(_: *sriracha.Window) void {
    sriracha.app.terminate();
}
```

## API

### Window

```zig
// Lifecycle
window.create(opts)         // Create with title, size, position, style, callbacks
window.destroy()            // Destroy the window
window.close()              // Post a close event (triggers on_close callback)
window.show() / .hide()

// Properties
window.setTitle(title)
window.setFrame(x, y, w, h, animated)
window.getFrame() -> Rect
window.setMinSize(w, h) / .setMaxSize(w, h)

// Style
window.setStyleMask(mask)   // StyleMask.default, .borderless, .resizable, etc.
window.setAlphaValue(0.8)   // Window transparency
window.toggleFullScreen()

// Positioning
window.center()
window.miniaturize() / .deminiaturize()
window.orderFront() / .orderBack()
```

### WebView

```zig
// Lifecycle
webview.create(opts)              // opts.on_script_message for JS-to-Zig messaging
webview.destroy()
webview.attachToWindow(&window)
webview.detachFromWindow()

// Navigation
webview.loadURL("https://example.com")
webview.loadHTML("<h1>Hello</h1>", null)
webview.reload()
webview.goBack() / .goForward()

// JavaScript
webview.evaluateJavaScript("document.title = 'Hello'")
```

### JS-to-Zig Messaging

Send messages from JavaScript to Zig:

```javascript
// In your HTML/JS
window.webkit.messageHandlers.sriracha.postMessage("hello from js!");
```

```zig
// In Zig
webview.create(.{ .on_script_message = onMessage });

fn onMessage(_: *sriracha.WebView, message: []const u8) void {
    std.debug.print("JS says: {s}\n", .{message});
}
```

### Timers

```zig
// Schedule a one-shot callback (seconds)
sriracha.scheduleCallback(2, &myCallback);
```

## License

MIT
