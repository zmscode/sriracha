const builtin = @import("builtin");

pub const is_windows = builtin.os.tag == .windows;
pub const is_macos = builtin.os.tag == .macos;
pub const is_linux = builtin.os.tag == .linux;

pub const app = if (is_windows) @import("platform/windows/app.zig") else if (is_linux) @import("platform/linux/app.zig") else @import("platform/macos/app.zig");

const window_mod = if (is_windows) @import("platform/windows/window.zig") else if (is_linux) @import("platform/linux/window.zig") else @import("platform/macos/window.zig");
const webview_mod = if (is_windows) @import("platform/windows/webview.zig") else if (is_linux) @import("platform/linux/webview.zig") else @import("platform/macos/webview.zig");

pub const Window = window_mod.Window;
pub const WebView = webview_mod.WebView;
pub const StyleMask = window_mod.StyleMask;
pub const Size = window_mod.Size;
pub const Point = window_mod.Point;
pub const Rect = window_mod.Rect;
pub const WindowCallbacks = window_mod.WindowCallbacks;

/// Schedule a one-shot callback after the given number of seconds.
/// Works across all platforms (GCD on macOS, WM_TIMER on Windows, g_timeout_add on Linux).
pub fn scheduleCallback(seconds: u64, func: *const fn (?*anyopaque) callconv(.c) void) void {
    if (is_windows) {
        @import("platform/windows/window.zig").scheduleTimer(@intCast(seconds * 1000), func);
    } else if (is_linux) {
        const gtk = @import("platform/linux/gtk.zig");
        const wrapper = struct {
            fn call(_: gtk.gpointer) callconv(.c) gtk.gboolean {
                func(null);
                return gtk.FALSE;
            }
        };
        _ = gtk.g_timeout_add(@intCast(seconds * 1000), @ptrCast(&wrapper.call), null);
    } else {
        const gcd = struct {
            extern "System" fn dispatch_time(when: u64, delta: i64) u64;
            extern "System" fn dispatch_after_f(when: u64, queue: *anyopaque, context: ?*anyopaque, work: *const fn (?*anyopaque) callconv(.c) void) void;
        };
        const dispatch_main_q = @extern(*anyopaque, .{ .name = "_dispatch_main_q" });
        const when = gcd.dispatch_time(0, @intCast(seconds * 1_000_000_000));
        gcd.dispatch_after_f(when, dispatch_main_q, null, func);
    }
}
