const std = @import("std");
const gtk = @import("gtk.zig");
const Window = @import("window.zig").Window;

pub const WebView = struct {
    native: ?*gtk.GtkWidget = null,
    content_manager: ?*gtk.WebKitUserContentManager = null,
    window: ?*Window = null,
    handler_name: []const u8 = "sriracha",
    on_script_message: ?*const fn (*WebView, []const u8) void = null,

    pub const CreateOptions = struct {
        handler_name: []const u8 = "sriracha",
        on_script_message: ?*const fn (*WebView, []const u8) void = null,
    };

    pub fn create(self: *WebView, opts: CreateOptions) void {
        const alloc = std.heap.page_allocator;
        self.handler_name = opts.handler_name;
        self.on_script_message = opts.on_script_message;

        // Create content manager and register script message handler
        const manager = gtk.webkit_user_content_manager_new() orelse return;
        self.content_manager = manager;

        const prefix = "script-message-received::";
        const signal_len = prefix.len + opts.handler_name.len;
        const signal_z = alloc.allocSentinel(u8, signal_len, 0) catch return;
        defer alloc.free(signal_z[0 .. signal_len + 1]);
        @memcpy(signal_z[0..prefix.len], prefix);
        @memcpy(signal_z[prefix.len..][0..opts.handler_name.len], opts.handler_name);

        // Connect signal before registering handler
        _ = gtk.g_signal_connect_data(
            @ptrCast(manager),
            signal_z.ptr,
            @ptrCast(&onScriptMessage),
            @ptrCast(self),
            null,
            0,
        );

        // Register the handler name
        const name_z = alloc.allocSentinel(u8, opts.handler_name.len, 0) catch return;
        defer alloc.free(name_z[0 .. opts.handler_name.len + 1]);
        @memcpy(name_z[0..opts.handler_name.len], opts.handler_name);
        _ = gtk.webkit_user_content_manager_register_script_message_handler(manager, name_z.ptr);

        // Create WebView with the content manager
        self.native = gtk.webkit_web_view_new_with_user_content_manager(manager);
    }

    pub fn attachToWindow(self: *WebView, win: *Window) void {
        self.window = win;
        const wv = self.native orelse return;
        const w = win.native orelse return;
        gtk.gtk_container_add(w, wv);
        gtk.gtk_widget_show(wv);
        win.content_view = wv;
    }

    pub fn loadURL(self: *WebView, url: []const u8) void {
        const wv = self.native orelse return;
        const alloc = std.heap.page_allocator;
        const url_z = alloc.allocSentinel(u8, url.len, 0) catch return;
        defer alloc.free(url_z[0 .. url.len + 1]);
        @memcpy(url_z[0..url.len], url);
        gtk.webkit_web_view_load_uri(wv, url_z.ptr);
    }

    pub fn loadHTML(self: *WebView, html: []const u8, base_url: ?[]const u8) void {
        const wv = self.native orelse return;

        // Null-terminate HTML
        const alloc = std.heap.page_allocator;
        const html_z = alloc.allocSentinel(u8, html.len, 0) catch return;
        defer alloc.free(html_z[0 .. html.len + 1]);
        @memcpy(html_z[0..html.len], html);

        // Null-terminate base URL if provided
        var base_z: ?[*:0]const u8 = null;
        var base_alloc: ?[]u8 = null;
        if (base_url) |bu| {
            const ba = alloc.allocSentinel(u8, bu.len, 0) catch return;
            @memcpy(ba[0..bu.len], bu);
            base_z = ba.ptr;
            base_alloc = ba[0 .. bu.len + 1];
        }
        defer if (base_alloc) |ba| alloc.free(ba);

        gtk.webkit_web_view_load_html(wv, html_z.ptr, base_z);
    }

    pub fn reload(self: *WebView) void {
        const wv = self.native orelse return;
        gtk.webkit_web_view_reload(wv);
    }

    pub fn goBack(self: *WebView) void {
        const wv = self.native orelse return;
        gtk.webkit_web_view_go_back(wv);
    }

    pub fn goForward(self: *WebView) void {
        const wv = self.native orelse return;
        gtk.webkit_web_view_go_forward(wv);
    }

    pub fn evaluateJavaScript(self: *WebView, js: []const u8) void {
        const wv = self.native orelse return;
        gtk.webkit_web_view_evaluate_javascript(
            wv,
            js.ptr,
            @intCast(js.len),
            null,
            null,
            null,
            null,
            null,
        );
    }

    pub fn detachFromWindow(self: *WebView) void {
        if (self.window) |win| {
            if (self.native) |wv| {
                if (win.native) |w| {
                    gtk.gtk_container_remove(w, wv);
                }
            }
            win.content_view = null;
        }
        self.window = null;
    }

    pub fn destroy(self: *WebView) void {
        const alloc = std.heap.page_allocator;
        self.detachFromWindow();

        if (self.content_manager) |manager| {
            if (alloc.allocSentinel(u8, self.handler_name.len, 0)) |name_z| {
                defer alloc.free(name_z[0 .. self.handler_name.len + 1]);
                @memcpy(name_z[0..self.handler_name.len], self.handler_name);
                gtk.webkit_user_content_manager_unregister_script_message_handler(manager, name_z.ptr);
            }
        }

        if (self.native) |wv| {
            gtk.gtk_widget_destroy(wv);
        }

        self.native = null;
        self.content_manager = null;
    }

    // --------------------------------------------------------
    // Signal handler
    // --------------------------------------------------------

    fn onScriptMessage(_: *gtk.WebKitUserContentManager, js_result: *gtk.WebKitJavascriptResult, user_data: ?*anyopaque) callconv(.c) void {
        const self: *WebView = @ptrCast(@alignCast(user_data orelse return));
        const cb = self.on_script_message orelse return;

        const value = gtk.webkit_javascript_result_get_js_value(js_result) orelse return;
        const str = gtk.jsc_value_to_string(value) orelse return;
        defer gtk.g_free(@ptrCast(str));

        // Find string length
        var len: usize = 0;
        while (str[len] != 0) : (len += 1) {}

        cb(self, str[0..len]);
    }
};
