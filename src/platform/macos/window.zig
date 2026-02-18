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
        const frame = objc.msgSend_stret_rect(w.native, objc.sel("frame"));
        if (w.callbacks.on_resize) |cb| cb(w, frame.size);
    }

    fn windowDidMove(self_obj: objc.id, _sel: objc.SEL, notification: objc.id) callconv(.c) void {
        _ = .{ _sel, notification };
        const w = getWindowFromDelegate(self_obj);
        const frame = objc.msgSend_stret_rect(w.native, objc.sel("frame"));
        if (w.callbacks.on_move) |cb| cb(w, frame.origin);
    }

    fn windowDidBecomeKey(self_obj: objc.id, _sel: objc.SEL, notification: objc.id) callconv(.c) void {
        _ = .{ _sel, notification };
        const w = getWindowFromDelegate(self_obj);
        if (w.callbacks.on_focus) |cb| cb(w);
    }

    fn windowDidResignKey(self_obj: objc.id, _sel: objc.SEL, notification: objc.id) callconv(.c) void {
        _ = .{ _sel, notification };
        const w = getWindowFromDelegate(self_obj);
        if (w.callbacks.on_blur) |cb| cb(w);
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
        const buttons = [_]objc.NSUInteger{
            WindowButton.close,
            WindowButton.miniaturize,
            WindowButton.zoom,
        };
        const spacing: f64 = 20;
        for (buttons, 0..) |btn_type, i| {
            const btn = self.getStandardButton(btn_type);
            if (btn != null) {
                objc.msgSend_point_void(btn, objc.sel("setFrameOrigin:"), .{
                    .x = x + @as(f64, @floatFromInt(i)) * spacing,
                    .y = y,
                });
            }
        }
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
