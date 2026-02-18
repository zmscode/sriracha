const objc = @import("objc");
const Window = @import("window.zig").Window;

pub const WebView = struct {
    native: objc.id = null,
    configuration: objc.id = null,
    content_controller: objc.id = null,
    message_handler: objc.id = null,
    handler_name: []const u8 = "sriracha",
    on_script_message: ?*const fn (*WebView, objc.id) void = null,
    window: ?*Window = null,

    var handler_class_registered: bool = false;

    fn initHandlerClass() void {
        if (handler_class_registered) return;

        const cls = objc.allocateClassPair("NSObject", "SrirachaMessageHandler") orelse
            @panic("Failed to create SrirachaMessageHandler class");

        _ = objc.addIvar(cls, "_zig_webview", @sizeOf(usize), @alignOf(usize), "^v");
        _ = objc.addProtocol(cls, "WKScriptMessageHandler");
        _ = objc.addMethod(
            cls,
            objc.sel("userContentController:didReceiveScriptMessage:"),
            @ptrCast(&handleScriptMessage),
            "v@:@@",
        );

        objc.registerClassPair(cls);
        handler_class_registered = true;
    }

    fn handleScriptMessage(self_obj: objc.id, _sel: objc.SEL, controller: objc.id, message: objc.id) callconv(.c) void {
        _ = .{ _sel, controller };
        const wv: *WebView = @ptrCast(@alignCast(objc.getIvar(self_obj, "_zig_webview")));
        if (wv.on_script_message) |cb| cb(wv, message);
    }


    pub const CreateOptions = struct {
        handler_name: []const u8 = "sriracha",
        on_script_message: ?*const fn (*WebView, objc.id) void = null,
    };

    pub fn create(self: *WebView, opts: CreateOptions) void {
        initHandlerClass();

        const config_alloc = objc.msgSend(objc.getClass("WKWebViewConfiguration"), objc.sel("alloc"));
        self.configuration = objc.msgSend(config_alloc, objc.sel("init"));
        self.content_controller = objc.msgSend(self.configuration, objc.sel("userContentController"));

        const handler_alloc = objc.msgSend(objc.getClass("SrirachaMessageHandler"), objc.sel("alloc"));
        self.message_handler = objc.msgSend(handler_alloc, objc.sel("init"));
        objc.setIvar(self.message_handler, "_zig_webview", @ptrCast(self));

        objc.msgSend_id_id_void(
            self.content_controller,
            objc.sel("addScriptMessageHandler:name:"),
            self.message_handler,
            objc.nsString(opts.handler_name),
        );

        self.handler_name = opts.handler_name;
        self.on_script_message = opts.on_script_message;

        const wv_alloc = objc.msgSend(objc.getClass("WKWebView"), objc.sel("alloc"));
        self.native = objc.msgSend_rect_id(
            wv_alloc,
            objc.sel("initWithFrame:configuration:"),
            objc.makeRect(0, 0, 0, 0),
            self.configuration,
        );

        self.window = null;
    }


    pub fn loadURL(self: *WebView, url: []const u8) void {
        const request = objc.msgSend_id(
            objc.getClass("NSURLRequest"),
            objc.sel("requestWithURL:"),
            objc.nsURL(url),
        );
        _ = objc.msgSend_id(self.native, objc.sel("loadRequest:"), request);
    }

    pub fn loadHTML(self: *WebView, html: []const u8, base_url: ?[]const u8) void {
        const ns_base: objc.id = if (base_url) |bu| objc.nsURL(bu) else null;
        _ = objc.msgSend_id_id(
            self.native,
            objc.sel("loadHTMLString:baseURL:"),
            objc.nsString(html),
            ns_base,
        );
    }

    pub fn reload(self: *WebView) void {
        _ = objc.msgSend(self.native, objc.sel("reload"));
    }

    pub fn goBack(self: *WebView) void {
        _ = objc.msgSend(self.native, objc.sel("goBack"));
    }

    pub fn goForward(self: *WebView) void {
        _ = objc.msgSend(self.native, objc.sel("goForward"));
    }


    pub fn evaluateJavaScript(self: *WebView, js: []const u8) void {
        objc.msgSend_id_id_void(
            self.native,
            objc.sel("evaluateJavaScript:completionHandler:"),
            objc.nsString(js),
            null,
        );
    }


    pub fn attachToWindow(self: *WebView, win: *Window) void {
        win.setContentView(self.native);
        self.window = win;
    }

    pub fn detachFromWindow(self: *WebView) void {
        if (self.window) |w| {
            const empty_alloc = objc.msgSend(objc.getClass("NSView"), objc.sel("alloc"));
            const empty_view = objc.msgSend(empty_alloc, objc.sel("init"));
            w.setContentView(empty_view);
            self.window = null;
        }
    }


    pub fn destroy(self: *WebView) void {
        self.detachFromWindow();

        objc.msgSend_id_void(
            self.content_controller,
            objc.sel("removeScriptMessageHandlerForName:"),
            objc.nsString(self.handler_name),
        );

        objc.msgSend_void(self.message_handler, objc.sel("release"));
        objc.msgSend_void(self.native, objc.sel("release"));

        self.native = null;
        self.configuration = null;
        self.content_controller = null;
        self.message_handler = null;
        self.on_script_message = null;
    }
};
