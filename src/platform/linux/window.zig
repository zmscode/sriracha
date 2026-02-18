const std = @import("std");
const gtk = @import("gtk.zig");

// ============================================================
// Geometry types (match macOS / Windows API)
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
// StyleMask — maps macOS style flags to GTK concepts
// ============================================================

pub const StyleMask = struct {
    pub const borderless: u32 = 0;
    pub const titled: u32 = 1;
    pub const closable: u32 = 2;
    pub const miniaturizable: u32 = 4;
    pub const resizable: u32 = 8;
    pub const full_size_content_view: u32 = 0;
    pub const fullscreen: u32 = 0;
    pub const default: u32 = titled | closable | miniaturizable | resizable;
};

// ============================================================
// WindowButton — no direct GTK equivalent
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
    native: ?*gtk.GtkWidget = null,
    callbacks: WindowCallbacks = .{},
    content_view: ?*gtk.GtkWidget = null,

    // Track previous position/size for configure-event deduplication
    last_x: c_int = 0,
    last_y: c_int = 0,
    last_w: c_int = 0,
    last_h: c_int = 0,

    // Fullscreen state
    is_fullscreen: bool = false,

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
    // Signal handlers
    // --------------------------------------------------------

    fn onDeleteEvent(widget: *gtk.GtkWidget, _: ?*anyopaque, user_data: ?*anyopaque) callconv(.c) gtk.gboolean {
        _ = widget;
        const self: *Window = @ptrCast(@alignCast(user_data orelse return gtk.FALSE));
        if (self.callbacks.on_close) |cb| {
            cb(self);
            return gtk.TRUE; // handled — don't destroy
        }
        return gtk.FALSE; // allow default destroy
    }

    fn onConfigureEvent(widget: *gtk.GtkWidget, event: *gtk.GdkEventConfigure, user_data: ?*anyopaque) callconv(.c) gtk.gboolean {
        _ = widget;
        const self: *Window = @ptrCast(@alignCast(user_data orelse return gtk.FALSE));

        // Check for size change
        if (event.width != self.last_w or event.height != self.last_h) {
            self.last_w = event.width;
            self.last_h = event.height;
            if (self.callbacks.on_resize) |cb| {
                cb(self, .{
                    .width = @floatFromInt(event.width),
                    .height = @floatFromInt(event.height),
                });
            }
        }

        // Check for position change
        if (event.x != self.last_x or event.y != self.last_y) {
            self.last_x = event.x;
            self.last_y = event.y;
            if (self.callbacks.on_move) |cb| {
                cb(self, .{
                    .x = @floatFromInt(event.x),
                    .y = @floatFromInt(event.y),
                });
            }
        }

        return gtk.FALSE;
    }

    fn onFocusIn(_: *gtk.GtkWidget, _: ?*anyopaque, user_data: ?*anyopaque) callconv(.c) gtk.gboolean {
        const self: *Window = @ptrCast(@alignCast(user_data orelse return gtk.FALSE));
        if (self.callbacks.on_focus) |cb| cb(self);
        return gtk.FALSE;
    }

    fn onFocusOut(_: *gtk.GtkWidget, _: ?*anyopaque, user_data: ?*anyopaque) callconv(.c) gtk.gboolean {
        const self: *Window = @ptrCast(@alignCast(user_data orelse return gtk.FALSE));
        if (self.callbacks.on_blur) |cb| cb(self);
        return gtk.FALSE;
    }

    // --------------------------------------------------------
    // Public methods
    // --------------------------------------------------------

    pub fn create(self: *Window, opts: CreateOptions) void {
        self.callbacks = opts.callbacks;

        const win = gtk.gtk_window_new(gtk.GTK_WINDOW_TOPLEVEL) orelse return;
        self.native = win;

        // Title
        var title_buf: [256:0]u8 = @splat(0);
        const len = @min(opts.title.len, title_buf.len - 1);
        @memcpy(title_buf[0..len], opts.title[0..len]);
        gtk.gtk_window_set_title(win, &title_buf);

        // Size and position
        gtk.gtk_window_set_default_size(win, @intFromFloat(opts.width), @intFromFloat(opts.height));
        gtk.gtk_window_move(win, @intFromFloat(opts.x), @intFromFloat(opts.y));

        // Borderless
        if (opts.style == StyleMask.borderless) {
            gtk.gtk_window_set_decorated(win, gtk.FALSE);
        }

        // Resizable
        if (opts.style & StyleMask.resizable == 0 and opts.style != StyleMask.borderless) {
            // Not resizable — set geometry hints to fix size
            const geom = gtk.GdkGeometry{
                .min_width = @intFromFloat(opts.width),
                .min_height = @intFromFloat(opts.height),
                .max_width = @intFromFloat(opts.width),
                .max_height = @intFromFloat(opts.height),
                .base_width = 0,
                .base_height = 0,
                .width_inc = 0,
                .height_inc = 0,
                .min_aspect = 0,
                .max_aspect = 0,
                .win_gravity = 0,
            };
            gtk.gtk_window_set_geometry_hints(win, null, &geom, gtk.GDK_HINT_MIN_SIZE | gtk.GDK_HINT_MAX_SIZE);
        }

        // Connect signals
        _ = gtk.g_signal_connect_data(@ptrCast(win), "delete-event", @ptrCast(&onDeleteEvent), @ptrCast(self), null, 0);
        _ = gtk.g_signal_connect_data(@ptrCast(win), "configure-event", @ptrCast(&onConfigureEvent), @ptrCast(self), null, 0);
        _ = gtk.g_signal_connect_data(@ptrCast(win), "focus-in-event", @ptrCast(&onFocusIn), @ptrCast(self), null, 0);
        _ = gtk.g_signal_connect_data(@ptrCast(win), "focus-out-event", @ptrCast(&onFocusOut), @ptrCast(self), null, 0);
    }

    pub fn setTitle(self: *Window, title: []const u8) void {
        const win = self.native orelse return;
        var buf: [256:0]u8 = @splat(0);
        const len = @min(title.len, buf.len - 1);
        @memcpy(buf[0..len], title[0..len]);
        gtk.gtk_window_set_title(win, &buf);
    }

    pub fn setFrame(self: *Window, x: f64, y: f64, w: f64, h: f64, _: bool) void {
        const win = self.native orelse return;
        gtk.gtk_window_move(win, @intFromFloat(x), @intFromFloat(y));
        gtk.gtk_window_resize(win, @intFromFloat(w), @intFromFloat(h));
    }

    pub fn setMinSize(self: *Window, width: f64, height: f64) void {
        const win = self.native orelse return;
        const geom = gtk.GdkGeometry{
            .min_width = @intFromFloat(width),
            .min_height = @intFromFloat(height),
            .max_width = 0,
            .max_height = 0,
            .base_width = 0,
            .base_height = 0,
            .width_inc = 0,
            .height_inc = 0,
            .min_aspect = 0,
            .max_aspect = 0,
            .win_gravity = 0,
        };
        gtk.gtk_window_set_geometry_hints(win, null, &geom, gtk.GDK_HINT_MIN_SIZE);
    }

    pub fn setMaxSize(self: *Window, width: f64, height: f64) void {
        const win = self.native orelse return;
        const geom = gtk.GdkGeometry{
            .min_width = 0,
            .min_height = 0,
            .max_width = @intFromFloat(width),
            .max_height = @intFromFloat(height),
            .base_width = 0,
            .base_height = 0,
            .width_inc = 0,
            .height_inc = 0,
            .min_aspect = 0,
            .max_aspect = 0,
            .win_gravity = 0,
        };
        gtk.gtk_window_set_geometry_hints(win, null, &geom, gtk.GDK_HINT_MAX_SIZE);
    }

    pub fn getFrame(self: *const Window) Rect {
        const win = self.native orelse return .{ .origin = .{ .x = 0, .y = 0 }, .size = .{ .width = 0, .height = 0 } };
        var x: c_int = 0;
        var y: c_int = 0;
        var w: c_int = 0;
        var h: c_int = 0;
        gtk.gtk_window_get_position(win, &x, &y);
        gtk.gtk_window_get_size(win, &w, &h);
        return .{
            .origin = .{ .x = @floatFromInt(x), .y = @floatFromInt(y) },
            .size = .{ .width = @floatFromInt(w), .height = @floatFromInt(h) },
        };
    }

    pub fn show(self: *Window) void {
        const win = self.native orelse return;
        gtk.gtk_widget_show_all(win);
    }

    pub fn hide(self: *Window) void {
        const win = self.native orelse return;
        gtk.gtk_widget_hide(win);
    }

    pub fn miniaturize(self: *Window) void {
        const win = self.native orelse return;
        gtk.gtk_window_iconify(win);
    }

    pub fn deminiaturize(self: *Window) void {
        const win = self.native orelse return;
        gtk.gtk_window_deiconify(win);
    }

    pub fn center(self: *Window) void {
        const win = self.native orelse return;
        var w: c_int = 0;
        var h: c_int = 0;
        gtk.gtk_window_get_size(win, &w, &h);

        // Get workarea from primary monitor
        const screen = gtk.gtk_widget_get_screen(win) orelse return;
        const display = gtk.gdk_screen_get_display(screen) orelse return;
        const monitor = gtk.gdk_display_get_primary_monitor(display) orelse
            gtk.gdk_display_get_monitor(display, 0) orelse return;
        var workarea: gtk.GdkRectangle = undefined;
        gtk.gdk_monitor_get_workarea(monitor, &workarea);

        const x = workarea.x + @divTrunc(workarea.width - w, 2);
        const y = workarea.y + @divTrunc(workarea.height - h, 2);
        gtk.gtk_window_move(win, x, y);
    }

    pub fn close(self: *Window) void {
        const win = self.native orelse return;
        // Triggers delete-event signal
        gtk.gtk_widget_destroy(win);
        self.native = null;
    }

    pub fn destroy(self: *Window) void {
        const win = self.native orelse return;
        gtk.gtk_widget_destroy(win);
        self.native = null;
    }

    pub fn setContentView(self: *Window, view: ?*gtk.GtkWidget) void {
        const win = self.native orelse return;
        if (self.content_view) |old| {
            gtk.gtk_container_remove(win, old);
        }
        if (view) |v| {
            gtk.gtk_container_add(win, v);
            self.content_view = v;
        }
    }

    pub fn getContentView(self: *const Window) ?*gtk.GtkWidget {
        return self.content_view;
    }

    pub fn toggleFullScreen(self: *Window) void {
        const win = self.native orelse return;
        if (!self.is_fullscreen) {
            gtk.gtk_window_fullscreen(win);
            self.is_fullscreen = true;
        } else {
            gtk.gtk_window_unfullscreen(win);
            self.is_fullscreen = false;
        }
    }

    pub fn getStyleMask(self: *const Window) u32 {
        const win = self.native orelse return 0;
        if (gtk.gtk_window_get_decorated(win) == gtk.FALSE) {
            return StyleMask.borderless;
        }
        return StyleMask.default;
    }

    pub fn setStyleMask(self: *Window, mask: u32) void {
        const win = self.native orelse return;
        if (mask == StyleMask.borderless) {
            gtk.gtk_window_set_decorated(win, gtk.FALSE);
        } else {
            gtk.gtk_window_set_decorated(win, gtk.TRUE);
        }
    }

    pub fn setTitlebarAppearsTransparent(_: *Window, _: bool) void {
        // No direct GTK equivalent
    }

    pub fn setTitleVisibility(_: *Window, _: bool) void {
        // No direct GTK equivalent
    }

    pub fn getStandardButton(_: *const Window, _: u32) ?*anyopaque {
        return null;
    }

    pub fn setTrafficLightPosition(_: *Window, _: f64, _: f64) void {
        // No equivalent on Linux
    }

    pub fn orderFront(self: *Window) void {
        const win = self.native orelse return;
        gtk.gtk_window_present(win);
    }

    pub fn orderBack(self: *Window) void {
        const win = self.native orelse return;
        gtk.gtk_window_set_keep_below(win, gtk.TRUE);
        // Reset immediately so it doesn't stay pinned below
        gtk.gtk_window_set_keep_below(win, gtk.FALSE);
    }

    pub fn setAlphaValue(self: *Window, alpha: f64) void {
        const win = self.native orelse return;
        gtk.gtk_widget_set_opacity(win, alpha);
    }

    pub fn getAlphaValue(self: *const Window) f64 {
        const win = self.native orelse return 1.0;
        return gtk.gtk_widget_get_opacity(win);
    }

    pub fn setOpaque(_: *Window, _: bool) void {
        // Handled by GTK compositing automatically
    }

    pub fn setBackgroundColor(_: *Window, _: u8, _: u8, _: u8) void {
        // GTK CSS-based theming; no simple equivalent
    }
};
