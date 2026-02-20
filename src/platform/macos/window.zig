const std = @import("std");
const objc = @import("objc");

// Platform-neutral geometry type aliases
pub const Size = objc.NSSize;
pub const Point = objc.NSPoint;
pub const Rect = objc.NSRect;

pub const StyleMask = struct {
    pub const borderless: objc.NSUInteger = 0;
    pub const titled: objc.NSUInteger = 1 << 0;
    pub const closable: objc.NSUInteger = 1 << 1;
    pub const miniaturizable: objc.NSUInteger = 1 << 2;
    pub const resizable: objc.NSUInteger = 1 << 3;
    pub const full_size_content_view: objc.NSUInteger = 1 << 15;
    pub const fullscreen: objc.NSUInteger = 1 << 14;
    pub const default: objc.NSUInteger = titled | closable | miniaturizable | resizable;
};

pub const WindowButton = struct {
    pub const close: objc.NSUInteger = 0;
    pub const miniaturize: objc.NSUInteger = 1;
    pub const zoom: objc.NSUInteger = 2;
};

const NSBackingStoreBuffered: objc.NSUInteger = 2;

pub const WindowCallbacks = struct {
    on_close: ?*const fn (*Window) void = null,
    on_resize: ?*const fn (*Window, Size) void = null,
    on_move: ?*const fn (*Window, Point) void = null,
    on_focus: ?*const fn (*Window) void = null,
    on_blur: ?*const fn (*Window) void = null,
};

pub const Window = struct {
    native: objc.id = null,
    delegate: objc.id = null,
    callbacks: WindowCallbacks = .{},
    traffic_light_position: ?Point = null,
    traffic_light_hit_proxies: [3]objc.id = .{ null, null, null },

    var delegate_class_registered: bool = false;

    fn initDelegateClass() void {
        if (delegate_class_registered) return;

        const cls = objc.allocateClassPair("NSObject", "SrirachaWindowDelegate") orelse
            @panic("Failed to create SrirachaWindowDelegate class");

        _ = objc.addIvar(cls, "_zig_window", @sizeOf(usize), @alignOf(usize), "^v");
        _ = objc.addProtocol(cls, "NSWindowDelegate");
        _ = objc.addMethod(cls, objc.sel("windowWillClose:"), @ptrCast(&windowWillClose), "v@:@");
        _ = objc.addMethod(cls, objc.sel("windowDidResize:"), @ptrCast(&windowDidResize), "v@:@");
        _ = objc.addMethod(cls, objc.sel("windowDidMove:"), @ptrCast(&windowDidMove), "v@:@");
        _ = objc.addMethod(cls, objc.sel("windowDidBecomeKey:"), @ptrCast(&windowDidBecomeKey), "v@:@");
        _ = objc.addMethod(cls, objc.sel("windowDidResignKey:"), @ptrCast(&windowDidResignKey), "v@:@");
        _ = objc.addMethod(cls, objc.sel("windowDidUpdate:"), @ptrCast(&windowDidUpdate), "v@:@");

        objc.registerClassPair(cls);
        delegate_class_registered = true;
    }

    fn getWindowFromDelegate(delegate_obj: objc.id) *Window {
        return @ptrCast(@alignCast(objc.getIvar(delegate_obj, "_zig_window")));
    }

    fn windowWillClose(self_obj: objc.id, _sel: objc.SEL, notification: objc.id) callconv(.c) void {
        _ = .{ _sel, notification };
        const w = getWindowFromDelegate(self_obj);
        if (w.callbacks.on_close) |cb| cb(w);
    }

    fn windowDidResize(self_obj: objc.id, _sel: objc.SEL, notification: objc.id) callconv(.c) void {
        _ = .{ _sel, notification };
        const w = getWindowFromDelegate(self_obj);
        w.reapplyTrafficLights();
        const frame = objc.msgSend_stret_rect(w.native, objc.sel("frame"));
        if (w.callbacks.on_resize) |cb| cb(w, frame.size);
    }

    fn windowDidMove(self_obj: objc.id, _sel: objc.SEL, notification: objc.id) callconv(.c) void {
        _ = .{ _sel, notification };
        const w = getWindowFromDelegate(self_obj);
        w.reapplyTrafficLights();
        const frame = objc.msgSend_stret_rect(w.native, objc.sel("frame"));
        if (w.callbacks.on_move) |cb| cb(w, frame.origin);
    }

    fn windowDidBecomeKey(self_obj: objc.id, _sel: objc.SEL, notification: objc.id) callconv(.c) void {
        _ = .{ _sel, notification };
        const w = getWindowFromDelegate(self_obj);
        w.reapplyTrafficLights();
        if (w.callbacks.on_focus) |cb| cb(w);
    }

    fn windowDidResignKey(self_obj: objc.id, _sel: objc.SEL, notification: objc.id) callconv(.c) void {
        _ = .{ _sel, notification };
        const w = getWindowFromDelegate(self_obj);
        if (w.callbacks.on_blur) |cb| cb(w);
    }

    fn windowDidUpdate(self_obj: objc.id, _sel: objc.SEL, notification: objc.id) callconv(.c) void {
        _ = .{ _sel, notification };
        const w = getWindowFromDelegate(self_obj);
        w.reapplyTrafficLights();
    }

    pub const CreateOptions = struct {
        x: f64 = 200,
        y: f64 = 200,
        width: f64 = 800,
        height: f64 = 600,
        title: []const u8 = "Sriracha",
        style: objc.NSUInteger = StyleMask.default,
        callbacks: WindowCallbacks = .{},
    };

    pub fn create(self: *Window, opts: CreateOptions) void {
        initDelegateClass();

        const rect = objc.makeRect(opts.x, opts.y, opts.width, opts.height);
        const alloc_obj = objc.msgSend(objc.getClass("NSWindow"), objc.sel("alloc"));
        self.native = objc.msgSend_rect_uint_uint_bool(
            alloc_obj,
            objc.sel("initWithContentRect:styleMask:backing:defer:"),
            rect,
            opts.style,
            NSBackingStoreBuffered,
            false,
        );

        self.setTitle(opts.title);

        const delegate_alloc = objc.msgSend(objc.getClass("SrirachaWindowDelegate"), objc.sel("alloc"));
        self.delegate = objc.msgSend(delegate_alloc, objc.sel("init"));
        objc.setIvar(self.delegate, "_zig_window", @ptrCast(self));
        objc.msgSend_id_void(self.native, objc.sel("setDelegate:"), self.delegate);

        self.callbacks = opts.callbacks;
    }

    pub fn setTitle(self: *Window, title: []const u8) void {
        objc.msgSend_id_void(self.native, objc.sel("setTitle:"), objc.nsString(title));
    }

    pub fn setFrame(self: *Window, x: f64, y: f64, w: f64, h: f64, animate: bool) void {
        objc.msgSend_rect_bool_bool_void(
            self.native,
            objc.sel("setFrame:display:animate:"),
            objc.makeRect(x, y, w, h),
            true,
            animate,
        );
    }

    pub fn setMinSize(self: *Window, width: f64, height: f64) void {
        objc.msgSend_size_void(self.native, objc.sel("setContentMinSize:"), .{ .width = width, .height = height });
    }

    pub fn setMaxSize(self: *Window, width: f64, height: f64) void {
        objc.msgSend_size_void(self.native, objc.sel("setContentMaxSize:"), .{ .width = width, .height = height });
    }

    pub fn getFrame(self: *const Window) Rect {
        return objc.msgSend_stret_rect(self.native, objc.sel("frame"));
    }

    pub fn show(self: *Window) void {
        self.reapplyTrafficLights();
        objc.msgSend_id_void(self.native, objc.sel("makeKeyAndOrderFront:"), null);
    }

    pub fn hide(self: *Window) void {
        objc.msgSend_id_void(self.native, objc.sel("orderOut:"), null);
    }

    pub fn miniaturize(self: *Window) void {
        objc.msgSend_id_void(self.native, objc.sel("miniaturize:"), null);
    }

    pub fn deminiaturize(self: *Window) void {
        objc.msgSend_id_void(self.native, objc.sel("deminiaturize:"), null);
    }

    pub fn center(self: *Window) void {
        objc.msgSend_void(self.native, objc.sel("center"));
    }

    pub fn close(self: *Window) void {
        objc.msgSend_void(self.native, objc.sel("close"));
    }

    pub fn destroy(self: *Window) void {
        for (&self.traffic_light_hit_proxies) |*proxy| {
            if (proxy.*) |btn| {
                objc.msgSend_void(btn, objc.sel("removeFromSuperview"));
                objc.msgSend_void(btn, objc.sel("release"));
                proxy.* = null;
            }
        }
        objc.msgSend_id_void(self.native, objc.sel("setDelegate:"), null);
        objc.msgSend_void(self.native, objc.sel("close"));
        objc.msgSend_void(self.delegate, objc.sel("release"));
        objc.msgSend_void(self.native, objc.sel("release"));
        self.native = null;
        self.delegate = null;
    }

    pub fn setContentView(self: *Window, view: objc.id) void {
        objc.msgSend_id_void(self.native, objc.sel("setContentView:"), view);
    }

    pub fn getContentView(self: *const Window) objc.id {
        return objc.msgSend(self.native, objc.sel("contentView"));
    }

    pub fn toggleFullScreen(self: *Window) void {
        objc.msgSend_id_void(self.native, objc.sel("toggleFullScreen:"), null);
    }

    pub fn getStyleMask(self: *const Window) objc.NSUInteger {
        return objc.msgSend_uint_ret(self.native, objc.sel("styleMask"));
    }

    pub fn setStyleMask(self: *Window, mask: objc.NSUInteger) void {
        objc.msgSend_uint(self.native, objc.sel("setStyleMask:"), mask);
    }

    pub fn setTitlebarAppearsTransparent(self: *Window, transparent: bool) void {
        objc.msgSend_bool(self.native, objc.sel("setTitlebarAppearsTransparent:"), transparent);
    }

    pub fn setTitleVisibility(self: *Window, hidden: bool) void {
        objc.msgSend_uint(self.native, objc.sel("setTitleVisibility:"), if (hidden) 1 else 0);
    }

    pub fn getStandardButton(self: *const Window, button: objc.NSUInteger) objc.id {
        return objc.msgSend_int_id(self.native, objc.sel("standardWindowButton:"), button);
    }

    pub fn setTrafficLightPosition(self: *Window, x: f64, y: f64) void {
        self.traffic_light_position = .{ .x = x, .y = y };
        self.reapplyTrafficLights();
    }

    fn reapplyTrafficLights(self: *Window) void {
        const pos = self.traffic_light_position orelse return;
        const x = pos.x;
        const y = pos.y;
        const close_btn = self.getStandardButton(WindowButton.close);
        if (close_btn == null) return;

        const button_parent = objc.msgSend(close_btn, objc.sel("superview"));
        if (button_parent == null) return;
        objc.msgSend_void(button_parent, objc.sel("layoutSubtreeIfNeeded"));

        const parent_bounds = objc.msgSend_stret_rect(button_parent, objc.sel("bounds"));

        const mini_btn = self.getStandardButton(WindowButton.miniaturize);
        const zoom_btn = self.getStandardButton(WindowButton.zoom);
        const buttons = [_]objc.id{ close_btn, mini_btn, zoom_btn };
        const spacing: f64 = 6.0;

        // Clamp requested position so the entire traffic-light group stays inside
        // the titlebar parent bounds.
        var total_width: f64 = 0;
        var max_height: f64 = 0;
        var count: usize = 0;
        for (buttons) |btn| {
            if (btn == null) continue;
            const f = objc.msgSend_stret_rect(btn, objc.sel("frame"));
            total_width += f.size.width;
            max_height = @max(max_height, f.size.height);
            count += 1;
        }
        if (count == 0) return;
        if (count > 1) total_width += spacing * @as(f64, @floatFromInt(count - 1));

        const max_start_x = @max(0.0, parent_bounds.size.width - total_width);
        const clamped_x = std.math.clamp(x, 0.0, max_start_x);

        const max_top = @max(0.0, parent_bounds.size.height - max_height);
        const clamped_top = std.math.clamp(y, 0.0, max_top);
        const clamped_bottom_y = parent_bounds.size.height - max_height - clamped_top;

        var next_x = clamped_x;
        const actions = [_]objc.SEL{
            objc.sel("performClose:"),
            objc.sel("performMiniaturize:"),
            objc.sel("performZoom:"),
        };
        for (buttons, 0..) |btn, i| {
            if (btn == null) continue;
            objc.msgSend_bool(btn, objc.sel("setHidden:"), false);
            var btn_frame = objc.msgSend_stret_rect(btn, objc.sel("frame"));
            btn_frame.origin = .{ .x = next_x, .y = clamped_bottom_y };
            objc.msgSend_point_void(btn, objc.sel("setFrameOrigin:"), btn_frame.origin);
            // Refresh tracking/hit regions after frame change.
            objc.msgSend_void(btn, objc.sel("updateTrackingAreas"));
            objc.msgSend_void(btn, objc.sel("resetCursorRects"));
            self.ensureTrafficLightHitProxy(i, button_parent, btn_frame, actions[i]);
            next_x += btn_frame.size.width + spacing;
        }

        objc.msgSend_void(button_parent, objc.sel("updateTrackingAreas"));
        objc.msgSend_void(button_parent, objc.sel("resetCursorRects"));
        objc.msgSend_void(button_parent, objc.sel("layoutSubtreeIfNeeded"));
        objc.msgSend_void(self.native, objc.sel("displayIfNeeded"));
    }

    fn ensureTrafficLightHitProxy(self: *Window, index: usize, parent: objc.id, frame: Rect, action: objc.SEL) void {
        var proxy = self.traffic_light_hit_proxies[index];
        if (proxy == null) {
            const alloc_btn = objc.msgSend(objc.getClass("NSButton"), objc.sel("alloc"));
            proxy = objc.msgSend_rect(alloc_btn, objc.sel("initWithFrame:"), frame);
            if (proxy == null) return;

            objc.msgSend_id_void(proxy, objc.sel("setTitle:"), objc.nsString(""));
            objc.msgSend_bool(proxy, objc.sel("setBordered:"), false);
            objc.msgSend_bool(proxy, objc.sel("setTransparent:"), true);
            objc.msgSend_bool(proxy, objc.sel("setRefusesFirstResponder:"), true);
            objc.msgSend_f64_void(proxy, objc.sel("setAlphaValue:"), 0.001);
            objc.msgSend_id_void(proxy, objc.sel("setTarget:"), self.native);
            objc.msgSend_sel_void(proxy, objc.sel("setAction:"), action);
            objc.msgSend_id_void(parent, objc.sel("addSubview:"), proxy);
            self.traffic_light_hit_proxies[index] = proxy;
        }

        objc.msgSend_point_void(proxy, objc.sel("setFrameOrigin:"), frame.origin);
        objc.msgSend_size_void(proxy, objc.sel("setFrameSize:"), frame.size);
        objc.msgSend_bool(proxy, objc.sel("setHidden:"), false);
    }

    pub fn orderFront(self: *Window) void {
        objc.msgSend_id_void(self.native, objc.sel("orderFront:"), null);
    }

    pub fn orderBack(self: *Window) void {
        objc.msgSend_id_void(self.native, objc.sel("orderBack:"), null);
    }

    // -- Transparency --

    /// Set window alpha (0.0 = fully transparent, 1.0 = fully opaque).
    pub fn setAlphaValue(self: *Window, alpha: f64) void {
        objc.msgSend_f64_void(self.native, objc.sel("setAlphaValue:"), alpha);
    }

    pub fn getAlphaValue(self: *const Window) f64 {
        return objc.msgSend_f64_ret(self.native, objc.sel("alphaValue"));
    }

    /// Set whether the window is opaque. Set to false to allow transparency
    /// through the window background.
    pub fn setOpaque(self: *Window, is_opaque: bool) void {
        objc.msgSend_bool(self.native, objc.sel("setOpaque:"), is_opaque);
    }

    /// Set the window background color. Pass null for a clear background.
    pub fn setBackgroundColor(self: *Window, color: objc.id) void {
        objc.msgSend_id_void(self.native, objc.sel("setBackgroundColor:"), color);
    }
};
