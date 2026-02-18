// ============================================================
// Minimal GTK3 / GLib / WebKitGTK / JSC bindings for Sriracha
// ============================================================

// ============================================================
// Opaque types
// ============================================================

pub const GtkWidget = opaque {};
pub const GdkScreen = opaque {};
pub const GdkMonitor = opaque {};
pub const GdkDisplay = opaque {};
pub const GdkRectangle = extern struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};
pub const WebKitWebView = opaque {};
pub const WebKitUserContentManager = opaque {};
pub const WebKitJavascriptResult = opaque {};
pub const JSCValue = opaque {};
pub const GCancellable = opaque {};

// ============================================================
// GLib types and constants
// ============================================================

pub const gboolean = c_int;
pub const gpointer = ?*anyopaque;
pub const gulong = c_ulong;
pub const GCallback = *const fn () callconv(.c) void;
pub const GSourceFunc = *const fn (gpointer) callconv(.c) gboolean;

pub const TRUE: gboolean = 1;
pub const FALSE: gboolean = 0;

// GdkEventConfigure — for configure-event signal
pub const GdkEventConfigure = extern struct {
    type: c_int,
    window: ?*anyopaque,
    send_event: i8,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};

// GdkGeometry — for gtk_window_set_geometry_hints
pub const GdkGeometry = extern struct {
    min_width: c_int,
    min_height: c_int,
    max_width: c_int,
    max_height: c_int,
    base_width: c_int,
    base_height: c_int,
    width_inc: c_int,
    height_inc: c_int,
    min_aspect: f64,
    max_aspect: f64,
    win_gravity: c_int,
};

// GdkWindowHints flags
pub const GDK_HINT_MIN_SIZE: c_int = 1 << 1;
pub const GDK_HINT_MAX_SIZE: c_int = 1 << 2;

// GTK window type
pub const GTK_WINDOW_TOPLEVEL: c_int = 0;

// ============================================================
// GLib functions
// ============================================================

pub extern "c" fn g_signal_connect_data(
    instance: *anyopaque,
    detailed_signal: [*:0]const u8,
    c_handler: GCallback,
    data: ?*anyopaque,
    destroy_data: ?*const fn (?*anyopaque, ?*anyopaque) callconv(.c) void,
    connect_flags: c_int,
) callconv(.c) gulong;

pub extern "c" fn g_free(mem: ?*anyopaque) callconv(.c) void;
pub extern "c" fn g_idle_add(function: GSourceFunc, data: gpointer) callconv(.c) c_uint;
pub extern "c" fn g_timeout_add(interval: c_uint, function: GSourceFunc, data: gpointer) callconv(.c) c_uint;

// ============================================================
// GTK3 functions
// ============================================================

pub extern "c" fn gtk_init(argc: ?*c_int, argv: ?*?[*]?[*:0]u8) callconv(.c) void;
pub extern "c" fn gtk_main() callconv(.c) void;
pub extern "c" fn gtk_main_quit() callconv(.c) void;

// Window
pub extern "c" fn gtk_window_new(window_type: c_int) callconv(.c) ?*GtkWidget;
pub extern "c" fn gtk_window_set_title(window: *GtkWidget, title: [*:0]const u8) callconv(.c) void;
pub extern "c" fn gtk_window_set_default_size(window: *GtkWidget, width: c_int, height: c_int) callconv(.c) void;
pub extern "c" fn gtk_window_resize(window: *GtkWidget, width: c_int, height: c_int) callconv(.c) void;
pub extern "c" fn gtk_window_move(window: *GtkWidget, x: c_int, y: c_int) callconv(.c) void;
pub extern "c" fn gtk_window_get_position(window: *GtkWidget, root_x: *c_int, root_y: *c_int) callconv(.c) void;
pub extern "c" fn gtk_window_get_size(window: *GtkWidget, width: *c_int, height: *c_int) callconv(.c) void;
pub extern "c" fn gtk_window_fullscreen(window: *GtkWidget) callconv(.c) void;
pub extern "c" fn gtk_window_unfullscreen(window: *GtkWidget) callconv(.c) void;
pub extern "c" fn gtk_window_iconify(window: *GtkWidget) callconv(.c) void;
pub extern "c" fn gtk_window_deiconify(window: *GtkWidget) callconv(.c) void;
pub extern "c" fn gtk_window_present(window: *GtkWidget) callconv(.c) void;
pub extern "c" fn gtk_window_set_keep_below(window: *GtkWidget, setting: gboolean) callconv(.c) void;
pub extern "c" fn gtk_window_set_geometry_hints(
    window: *GtkWidget,
    geometry_widget: ?*GtkWidget,
    geometry: *const GdkGeometry,
    geom_mask: c_int,
) callconv(.c) void;
pub extern "c" fn gtk_window_set_decorated(window: *GtkWidget, setting: gboolean) callconv(.c) void;
pub extern "c" fn gtk_window_get_decorated(window: *GtkWidget) callconv(.c) gboolean;

// Widget
pub extern "c" fn gtk_widget_show_all(widget: *GtkWidget) callconv(.c) void;
pub extern "c" fn gtk_widget_show(widget: *GtkWidget) callconv(.c) void;
pub extern "c" fn gtk_widget_hide(widget: *GtkWidget) callconv(.c) void;
pub extern "c" fn gtk_widget_destroy(widget: *GtkWidget) callconv(.c) void;
pub extern "c" fn gtk_widget_set_opacity(widget: *GtkWidget, opacity: f64) callconv(.c) void;
pub extern "c" fn gtk_widget_get_opacity(widget: *GtkWidget) callconv(.c) f64;
pub extern "c" fn gtk_widget_grab_focus(widget: *GtkWidget) callconv(.c) void;
pub extern "c" fn gtk_widget_get_screen(widget: *GtkWidget) callconv(.c) ?*GdkScreen;
pub extern "c" fn gtk_widget_get_window(widget: *GtkWidget) callconv(.c) ?*anyopaque;
pub extern "c" fn gtk_widget_set_size_request(widget: *GtkWidget, width: c_int, height: c_int) callconv(.c) void;

// Container
pub extern "c" fn gtk_container_add(container: *GtkWidget, widget: *GtkWidget) callconv(.c) void;
pub extern "c" fn gtk_container_remove(container: *GtkWidget, widget: *GtkWidget) callconv(.c) void;

// Screen / monitor
pub extern "c" fn gdk_screen_get_display(screen: *GdkScreen) callconv(.c) ?*GdkDisplay;
pub extern "c" fn gdk_display_get_primary_monitor(display: *GdkDisplay) callconv(.c) ?*GdkMonitor;
pub extern "c" fn gdk_display_get_monitor(display: *GdkDisplay, monitor_num: c_int) callconv(.c) ?*GdkMonitor;
pub extern "c" fn gdk_monitor_get_workarea(monitor: *GdkMonitor, workarea: *GdkRectangle) callconv(.c) void;

// ============================================================
// WebKitGTK functions
// ============================================================

pub extern "c" fn webkit_web_view_new() callconv(.c) ?*GtkWidget;
pub extern "c" fn webkit_web_view_new_with_user_content_manager(manager: *WebKitUserContentManager) callconv(.c) ?*GtkWidget;
pub extern "c" fn webkit_web_view_load_uri(web_view: *GtkWidget, uri: [*:0]const u8) callconv(.c) void;
pub extern "c" fn webkit_web_view_load_html(web_view: *GtkWidget, content: [*:0]const u8, base_uri: ?[*:0]const u8) callconv(.c) void;
pub extern "c" fn webkit_web_view_reload(web_view: *GtkWidget) callconv(.c) void;
pub extern "c" fn webkit_web_view_go_back(web_view: *GtkWidget) callconv(.c) void;
pub extern "c" fn webkit_web_view_go_forward(web_view: *GtkWidget) callconv(.c) void;
pub extern "c" fn webkit_web_view_evaluate_javascript(
    web_view: *GtkWidget,
    script: [*]const u8,
    length: isize,
    world_name: ?[*:0]const u8,
    source_uri: ?[*:0]const u8,
    cancellable: ?*GCancellable,
    callback: ?*const fn (?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.c) void,
    user_data: ?*anyopaque,
) callconv(.c) void;

// UserContentManager
pub extern "c" fn webkit_user_content_manager_new() callconv(.c) ?*WebKitUserContentManager;
pub extern "c" fn webkit_user_content_manager_register_script_message_handler(
    manager: *WebKitUserContentManager,
    name: [*:0]const u8,
) callconv(.c) gboolean;
pub extern "c" fn webkit_user_content_manager_unregister_script_message_handler(
    manager: *WebKitUserContentManager,
    name: [*:0]const u8,
) callconv(.c) void;

// JavaScriptResult / JSCValue
pub extern "c" fn webkit_javascript_result_get_js_value(
    js_result: *WebKitJavascriptResult,
) callconv(.c) ?*JSCValue;
pub extern "c" fn jsc_value_to_string(value: *JSCValue) callconv(.c) ?[*:0]u8;
pub extern "c" fn jsc_value_is_string(value: *JSCValue) callconv(.c) gboolean;
