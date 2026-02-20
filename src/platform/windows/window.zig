const std = @import("std");
const win32 = @import("win32.zig");
const app = @import("app.zig");

// ============================================================
// Geometry types (match macOS objc.NSSize / objc.NSPoint / objc.NSRect)
// ============================================================

pub const Size = struct {
    width: f64,
    height: f64,
};

pub const Point = struct {
    x: f64,
    y: f64,
};

pub const Rect = struct {
    origin: Point,
    size: Size,
};

// ============================================================
// StyleMask — maps macOS style flags to Win32 WS_ constants
// ============================================================

pub const StyleMask = struct {
    pub const borderless: u32 = win32.WS_POPUP;
    pub const titled: u32 = win32.WS_CAPTION;
    pub const closable: u32 = win32.WS_SYSMENU;
    pub const miniaturizable: u32 = win32.WS_MINIMIZEBOX;
    pub const resizable: u32 = win32.WS_THICKFRAME | win32.WS_MAXIMIZEBOX;
    pub const full_size_content_view: u32 = 0; // no direct equivalent
    pub const fullscreen: u32 = 0; // managed via state tracking
    pub const default: u32 = win32.WS_OVERLAPPEDWINDOW;
};

// ============================================================
// WindowButton — no direct Win32 equivalent for repositioning
// ============================================================

pub const WindowButton = struct {
    pub const close: u32 = 0;
    pub const miniaturize: u32 = 1;
    pub const zoom: u32 = 2;
};

// ============================================================
// Callbacks
// ============================================================

pub const WindowCallbacks = struct {
    on_close: ?*const fn (*Window) void = null,
    on_resize: ?*const fn (*Window, Size) void = null,
    on_move: ?*const fn (*Window, Point) void = null,
    on_focus: ?*const fn (*Window) void = null,
    on_blur: ?*const fn (*Window) void = null,
};

// ============================================================
// Window struct
// ============================================================

pub const Window = struct {
    native: ?win32.HWND = null,
    callbacks: WindowCallbacks = .{},
    content_view: ?win32.HWND = null,
    bg_brush: ?win32.HBRUSH = null,

    // Min/max size constraints (enforced via WM_GETMINMAXINFO)
    min_width: ?f64 = null,
    min_height: ?f64 = null,
    max_width: ?f64 = null,
    max_height: ?f64 = null,

    // Fullscreen state tracking
    is_fullscreen: bool = false,
    pre_fullscreen_style: win32.DWORD = 0,
    pre_fullscreen_rect: win32.RECT = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 },

    // Alpha
    alpha: u8 = 255,

    // Timer callback table for WM_TIMER-based deferred execution
    const max_timers = 16;
    var timer_callbacks: [max_timers]?*const fn (?*anyopaque) callconv(.c) void = .{null} ** max_timers;

    var class_registered: bool = false;
    const CLASS_NAME = std.unicode.utf8ToUtf16LeStringLiteral("SrirachaWindow");

    pub const CreateOptions = struct {
        x: f64 = 200,
        y: f64 = 200,
        width: f64 = 800,
        height: f64 = 600,
        title: []const u8 = "Sriracha",
        style: u32 = StyleMask.default,
        callbacks: WindowCallbacks = .{},
    };

    // --------------------------------------------------------
    // Window class registration (one-time, like macOS initDelegateClass)
    // --------------------------------------------------------

    fn ensureClassRegistered() void {
        if (class_registered) return;

        const wc = win32.WNDCLASSEXW{
            .lpfnWndProc = &wndProc,
            .hInstance = app.getInstance(),
            .hCursor = win32.LoadCursorW(null, win32.IDC_ARROW),
            .lpszClassName = CLASS_NAME,
        };

        _ = win32.RegisterClassExW(&wc);
        class_registered = true;
    }

    // --------------------------------------------------------
    // WndProc — central message dispatcher
    // --------------------------------------------------------

    fn wndProc(hwnd: ?win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) callconv(.c) win32.LRESULT {
        const h = hwnd orelse return 0;

        // On WM_NCCREATE, extract the Window pointer from CREATESTRUCT
        if (msg == win32.WM_NCCREATE) {
            const cs: *win32.CREATESTRUCTW = @ptrFromInt(@as(usize, @bitCast(lparam)));
            if (cs.lpCreateParams) |params| {
                _ = win32.SetWindowLongPtrW(h, win32.GWLP_USERDATA, @as(win32.LONG_PTR, @bitCast(@intFromPtr(params))));
            }
            return win32.DefWindowProcW(h, msg, wparam, lparam);
        }

        const ptr = win32.GetWindowLongPtrW(h, win32.GWLP_USERDATA);
        if (ptr == 0) return win32.DefWindowProcW(h, msg, wparam, lparam);
        const self: *Window = @ptrFromInt(@as(usize, @bitCast(ptr)));

        switch (msg) {
            win32.WM_CLOSE => {
                if (self.callbacks.on_close) |cb| {
                    cb(self);
                } else {
                    // Default: destroy the window
                    _ = win32.DestroyWindow(h);
                }
                return 0;
            },
            win32.WM_SIZE => {
                // Resize the content view to fill the client area
                if (self.content_view) |cv| {
                    var rc: win32.RECT = undefined;
                    _ = win32.GetClientRect(h, &rc);
                    _ = win32.MoveWindow(cv, 0, 0, rc.right - rc.left, rc.bottom - rc.top, win32.TRUE);
                }
                if (self.callbacks.on_resize) |cb| {
                    const w: f64 = @floatFromInt(loword(lparam));
                    const ht: f64 = @floatFromInt(hiword(lparam));
                    cb(self, .{ .width = w, .height = ht });
                }
                return 0;
            },
            win32.WM_MOVE => {
                if (self.callbacks.on_move) |cb| {
                    const x: f64 = @floatFromInt(loword(lparam));
                    const y: f64 = @floatFromInt(hiword(lparam));
                    cb(self, .{ .x = x, .y = y });
                }
                return 0;
            },
            win32.WM_SETFOCUS => {
                if (self.callbacks.on_focus) |cb| cb(self);
                return 0;
            },
            win32.WM_KILLFOCUS => {
                if (self.callbacks.on_blur) |cb| cb(self);
                return 0;
            },
            win32.WM_GETMINMAXINFO => {
                const mmi: *win32.MINMAXINFO = @ptrFromInt(@as(usize, @bitCast(lparam)));
                if (self.min_width) |mw| mmi.ptMinTrackSize.x = @intFromFloat(mw);
                if (self.min_height) |mh| mmi.ptMinTrackSize.y = @intFromFloat(mh);
                if (self.max_width) |mw| mmi.ptMaxTrackSize.x = @intFromFloat(mw);
                if (self.max_height) |mh| mmi.ptMaxTrackSize.y = @intFromFloat(mh);
                return 0;
            },
            win32.WM_ERASEBKGND => {
                if (self.bg_brush) |brush| {
                    const hdc: win32.HDC = @ptrFromInt(wparam);
                    var rc: win32.RECT = undefined;
                    _ = win32.GetClientRect(h, &rc);
                    _ = win32.FillRect(hdc, &rc, brush);
                    return 1; // handled
                }
                return win32.DefWindowProcW(h, msg, wparam, lparam);
            },
            win32.WM_DESTROY => {
                // Clear the user-data pointer so no further messages
                // try to reference the (possibly freed) Window struct.
                _ = win32.SetWindowLongPtrW(h, win32.GWLP_USERDATA, 0);
                self.native = null;
                return 0;
            },
            else => {},
        }
        return win32.DefWindowProcW(h, msg, wparam, lparam);
    }

    // --------------------------------------------------------
    // Public methods
    // --------------------------------------------------------

    pub fn create(self: *Window, opts: CreateOptions) void {
        ensureClassRegistered();

        const wide_title = win32.utf8ToWide(opts.title) catch return;
        defer std.heap.page_allocator.free(wide_title);

        self.callbacks = opts.callbacks;

        self.native = win32.CreateWindowExW(
            0,
            CLASS_NAME,
            wide_title.ptr,
            opts.style | win32.WS_CLIPCHILDREN,
            @intFromFloat(opts.x),
            @intFromFloat(opts.y),
            @intFromFloat(opts.width),
            @intFromFloat(opts.height),
            null,
            null,
            app.getInstance(),
            @ptrCast(self),
        );
    }

    pub fn setTitle(self: *Window, title: []const u8) void {
        const hwnd = self.native orelse return;
        const wide = win32.utf8ToWide(title) catch return;
        defer std.heap.page_allocator.free(wide);
        _ = win32.SetWindowTextW(hwnd, wide.ptr);
    }

    pub fn setFrame(self: *Window, x: f64, y: f64, w: f64, h: f64, _: bool) void {
        const hwnd = self.native orelse return;
        _ = win32.MoveWindow(
            hwnd,
            @intFromFloat(x),
            @intFromFloat(y),
            @intFromFloat(w),
            @intFromFloat(h),
            win32.TRUE,
        );
    }

    pub fn setMinSize(self: *Window, width: f64, height: f64) void {
        self.min_width = width;
        self.min_height = height;
    }

    pub fn setMaxSize(self: *Window, width: f64, height: f64) void {
        self.max_width = width;
        self.max_height = height;
    }

    pub fn getFrame(self: *const Window) Rect {
        const hwnd = self.native orelse return .{ .origin = .{ .x = 0, .y = 0 }, .size = .{ .width = 0, .height = 0 } };
        var rc: win32.RECT = undefined;
        _ = win32.GetWindowRect(hwnd, &rc);
        return .{
            .origin = .{
                .x = @floatFromInt(rc.left),
                .y = @floatFromInt(rc.top),
            },
            .size = .{
                .width = @floatFromInt(rc.right - rc.left),
                .height = @floatFromInt(rc.bottom - rc.top),
            },
        };
    }

    pub fn show(self: *Window) void {
        const hwnd = self.native orelse return;
        _ = win32.ShowWindow(hwnd, win32.SW_SHOW);
        _ = win32.UpdateWindow(hwnd);
    }

    pub fn hide(self: *Window) void {
        const hwnd = self.native orelse return;
        _ = win32.ShowWindow(hwnd, win32.SW_HIDE);
    }

    pub fn miniaturize(self: *Window) void {
        const hwnd = self.native orelse return;
        _ = win32.ShowWindow(hwnd, win32.SW_MINIMIZE);
    }

    pub fn deminiaturize(self: *Window) void {
        const hwnd = self.native orelse return;
        _ = win32.ShowWindow(hwnd, win32.SW_RESTORE);
        _ = win32.SetForegroundWindow(hwnd);
    }

    pub fn center(self: *Window) void {
        const hwnd = self.native orelse return;
        var rc: win32.RECT = undefined;
        _ = win32.GetWindowRect(hwnd, &rc);
        const w = rc.right - rc.left;
        const h = rc.bottom - rc.top;
        const cx = win32.GetSystemMetrics(win32.SM_CXSCREEN);
        const cy = win32.GetSystemMetrics(win32.SM_CYSCREEN);
        const x = @divTrunc(cx - w, 2);
        const y = @divTrunc(cy - h, 2);
        _ = win32.MoveWindow(hwnd, x, y, w, h, win32.TRUE);
    }

    pub fn close(self: *Window) void {
        const hwnd = self.native orelse return;
        _ = win32.PostMessageW(hwnd, win32.WM_CLOSE, 0, 0);
    }

    pub fn destroy(self: *Window) void {
        const hwnd = self.native orelse return;
        if (self.bg_brush) |brush| {
            _ = win32.DeleteObject(@ptrCast(brush));
            self.bg_brush = null;
        }
        _ = win32.DestroyWindow(hwnd);
        self.native = null;
    }

    pub fn setContentView(self: *Window, view: ?win32.HWND) void {
        const hwnd = self.native orelse return;
        if (view) |v| {
            _ = win32.SetParent(v, hwnd);
            self.content_view = v;
            // Resize to fill client area
            var rc: win32.RECT = undefined;
            _ = win32.GetClientRect(hwnd, &rc);
            _ = win32.MoveWindow(v, 0, 0, rc.right - rc.left, rc.bottom - rc.top, win32.TRUE);
        }
    }

    pub fn getContentView(self: *const Window) ?win32.HWND {
        return self.content_view;
    }

    pub fn toggleFullScreen(self: *Window) void {
        const hwnd = self.native orelse return;
        if (!self.is_fullscreen) {
            // Save current state
            self.pre_fullscreen_style = @intCast(@as(u32, @truncate(@as(usize, @bitCast(win32.GetWindowLongPtrW(hwnd, win32.GWL_STYLE))))));
            _ = win32.GetWindowRect(hwnd, &self.pre_fullscreen_rect);
            // Strip decorations and fill screen
            const new_style = self.pre_fullscreen_style & ~win32.WS_OVERLAPPEDWINDOW;
            _ = win32.SetWindowLongPtrW(hwnd, win32.GWL_STYLE, @bitCast(@as(usize, new_style)));
            const cx = win32.GetSystemMetrics(win32.SM_CXSCREEN);
            const cy = win32.GetSystemMetrics(win32.SM_CYSCREEN);
            _ = win32.SetWindowPos(hwnd, win32.HWND_TOP, 0, 0, cx, cy, win32.SWP_FRAMECHANGED);
            self.is_fullscreen = true;
        } else {
            // Restore
            _ = win32.SetWindowLongPtrW(hwnd, win32.GWL_STYLE, @bitCast(@as(usize, self.pre_fullscreen_style)));
            const r = self.pre_fullscreen_rect;
            _ = win32.SetWindowPos(hwnd, null, r.left, r.top, r.right - r.left, r.bottom - r.top, win32.SWP_FRAMECHANGED);
            self.is_fullscreen = false;
        }
    }

    pub fn getStyleMask(self: *const Window) u32 {
        const hwnd = self.native orelse return 0;
        return @truncate(@as(usize, @bitCast(win32.GetWindowLongPtrW(hwnd, win32.GWL_STYLE))));
    }

    pub fn setStyleMask(self: *Window, mask: u32) void {
        const hwnd = self.native orelse return;
        _ = win32.SetWindowLongPtrW(hwnd, win32.GWL_STYLE, @bitCast(@as(usize, mask)));
        // Refresh the frame
        _ = win32.SetWindowPos(hwnd, null, 0, 0, 0, 0, win32.SWP_NOMOVE | win32.SWP_NOSIZE | win32.SWP_NOZORDER | win32.SWP_FRAMECHANGED);
    }

    pub fn setTitlebarAppearsTransparent(_: *Window, _: bool) void {
        // No direct Win32 equivalent
    }

    pub fn setTitleVisibility(_: *Window, _: bool) void {
        // No direct Win32 equivalent
    }

    pub fn getStandardButton(_: *const Window, _: u32) ?*anyopaque {
        // No direct Win32 equivalent
        return null;
    }

    pub fn setTrafficLightPosition(_: *Window, _: f64, _: f64) void {
        // No equivalent on Windows
    }

    pub fn orderFront(self: *Window) void {
        const hwnd = self.native orelse return;
        _ = win32.SetWindowPos(hwnd, win32.HWND_TOP, 0, 0, 0, 0, win32.SWP_NOMOVE | win32.SWP_NOSIZE);
    }

    pub fn orderBack(self: *Window) void {
        const hwnd = self.native orelse return;
        _ = win32.SetWindowPos(hwnd, win32.HWND_BOTTOM, 0, 0, 0, 0, win32.SWP_NOMOVE | win32.SWP_NOSIZE);
    }

    pub fn setAlphaValue(self: *Window, alpha: f64) void {
        const hwnd = self.native orelse return;
        self.alpha = @intFromFloat(std.math.clamp(alpha * 255.0, 0, 255));
        // Ensure WS_EX_LAYERED is set
        const ex_style: usize = @bitCast(win32.GetWindowLongPtrW(hwnd, win32.GWL_EXSTYLE));
        if (ex_style & win32.WS_EX_LAYERED == 0) {
            _ = win32.SetWindowLongPtrW(hwnd, win32.GWL_EXSTYLE, @bitCast(ex_style | win32.WS_EX_LAYERED));
        }
        _ = win32.SetLayeredWindowAttributes(hwnd, 0, self.alpha, win32.LWA_ALPHA);
    }

    pub fn getAlphaValue(self: *const Window) f64 {
        return @as(f64, @floatFromInt(self.alpha)) / 255.0;
    }

    pub fn setOpaque(self: *Window, is_opaque: bool) void {
        const hwnd = self.native orelse return;
        const ex_style: usize = @bitCast(win32.GetWindowLongPtrW(hwnd, win32.GWL_EXSTYLE));
        if (is_opaque) {
            _ = win32.SetWindowLongPtrW(hwnd, win32.GWL_EXSTYLE, @bitCast(ex_style & ~@as(usize, win32.WS_EX_LAYERED)));
        } else {
            _ = win32.SetWindowLongPtrW(hwnd, win32.GWL_EXSTYLE, @bitCast(ex_style | win32.WS_EX_LAYERED));
            _ = win32.SetLayeredWindowAttributes(hwnd, 0, self.alpha, win32.LWA_ALPHA);
        }
    }

    pub fn setBackgroundColor(self: *Window, r: u8, g: u8, b: u8) void {
        if (self.bg_brush) |old| {
            _ = win32.DeleteObject(@ptrCast(old));
        }
        self.bg_brush = win32.CreateSolidBrush(@as(win32.DWORD, r) | (@as(win32.DWORD, g) << 8) | (@as(win32.DWORD, b) << 16));
        if (self.native) |hwnd| {
            _ = win32.InvalidateRect(hwnd, null, win32.TRUE);
        }
    }

    // --------------------------------------------------------
    // Helpers
    // --------------------------------------------------------

    fn loword(l: win32.LPARAM) i16 {
        return @truncate(@as(isize, l));
    }

    fn hiword(l: win32.LPARAM) i16 {
        return @truncate(@as(isize, l) >> 16);
    }
};

/// Schedule a one-shot timer callback via WM_TIMER (no TIMERPROC function pointer).
/// This avoids heuristic AV false positives from SetTimer with callback pointers.
pub fn scheduleTimer(millis: u32, func: *const fn (?*anyopaque) callconv(.c) void) void {
    // Find a free slot
    var id: usize = 0;
    for (Window.timer_callbacks, 0..) |entry, i| {
        if (entry == null) {
            id = i + 1;
            break;
        }
    }
    if (id == 0) return;
    Window.timer_callbacks[id - 1] = func;

    // We need an HWND to receive WM_TIMER. Use a hidden message-only window.
    const hwnd = getTimerWindow();
    _ = win32.SetTimer(hwnd, id, millis, null);
}

var timer_hwnd: ?win32.HWND = null;

fn getTimerWindow() ?win32.HWND {
    if (timer_hwnd != null) return timer_hwnd;

    const S = struct {
        var registered: bool = false;
    };
    const TIMER_CLASS = std.unicode.utf8ToUtf16LeStringLiteral("SrirachaTimerWindow");
    if (!S.registered) {
        const wc = win32.WNDCLASSEXW{
            .lpfnWndProc = &timerWndProc,
            .hInstance = app.getInstance(),
            .lpszClassName = TIMER_CLASS,
        };
        _ = win32.RegisterClassExW(&wc);
        S.registered = true;
    }
    // HWND_MESSAGE makes it a message-only window (invisible, no taskbar entry)
    timer_hwnd = win32.CreateWindowExW(0, TIMER_CLASS, null, 0, 0, 0, 0, 0, win32.HWND_MESSAGE, null, app.getInstance(), null);
    return timer_hwnd;
}

fn timerWndProc(hwnd: ?win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) callconv(.c) win32.LRESULT {
    const h = hwnd orelse return 0;
    if (msg == win32.WM_TIMER) {
        const timer_id = wparam;
        if (timer_id > 0 and timer_id <= Window.max_timers) {
            _ = win32.KillTimer(h, timer_id);
            if (Window.timer_callbacks[timer_id - 1]) |cb| {
                Window.timer_callbacks[timer_id - 1] = null;
                cb(null);
            }
        }
        return 0;
    }
    return win32.DefWindowProcW(h, msg, wparam, lparam);
}
