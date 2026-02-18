const std = @import("std");
const builtin = @import("builtin");

const is_windows = builtin.os.tag == .windows;
const is_macos = builtin.os.tag == .macos;
const is_linux = builtin.os.tag == .linux;

const app = if (is_windows) @import("platform/windows/app.zig") else if (is_linux) @import("platform/linux/app.zig") else @import("platform/macos/app.zig");
const window_mod = if (is_windows) @import("platform/windows/window.zig") else if (is_linux) @import("platform/linux/window.zig") else @import("platform/macos/window.zig");
const webview_mod = if (is_windows) @import("platform/windows/webview.zig") else if (is_linux) @import("platform/linux/webview.zig") else @import("platform/macos/webview.zig");

pub const Window = window_mod.Window;
pub const StyleMask = window_mod.StyleMask;
pub const WebView = webview_mod.WebView;

const Size = window_mod.Size;
const Point = window_mod.Point;

const objc = if (is_macos) @import("objc") else struct {};

const Demo = enum {
    // -- Window lifecycle --
    window_create, // create + show + center
    window_destroy, // create, show, then destroy after 2s
    window_close, // create, show, then close after 2s (triggers on_close)

    // -- Window properties --
    window_set_title, // change title after showing
    window_set_frame, // animated move/resize
    window_min_max_size, // constrain window size
    window_get_frame, // read back current frame

    // -- Window visibility --
    window_show_hide, // show, hide after 1s, show again after 2s
    window_miniaturize, // miniaturize, deminiaturize after 2s
    window_center, // create off-center, then center

    // -- Window style --
    window_borderless, // create borderless window
    window_set_style_mask, // toggle between borderless and default
    window_transparent_titlebar, // fullSizeContentView + transparent titlebar
    window_title_visibility, // hide/show the title text

    // -- Window alpha --
    window_alpha, // transparent window with animated alpha

    // -- Window fullscreen --
    window_toggle_fullscreen, // enter fullscreen, exit after 3s

    // -- Window traffic lights --
    window_traffic_light_pos, // reposition close/minimize/zoom buttons

    // -- Window z-order --
    window_order_front_back, // two windows, swap z-order

    // -- Window callbacks --
    window_callbacks, // all callbacks: close, resize, move, focus, blur

    // -- WebView lifecycle --
    webview_create_destroy, // create webview, attach, then destroy after 3s

    // -- WebView navigation --
    webview_load_url, // load a URL
    webview_load_html, // load inline HTML
    webview_reload, // load URL then reload after 2s
    webview_back_forward, // load two URLs, go back, go forward

    // -- WebView JS --
    webview_eval_js, // evaluate JavaScript from Zig
    webview_js_to_zig, // JS sends message to Zig via postMessage

    // -- WebView attach/detach --
    webview_attach_detach, // attach to window, detach after 2s, reattach after 4s
};

var window: Window = .{};
var window2: Window = .{};
var webview: WebView = .{};
var current_demo: Demo = .webview_load_html;

pub fn main(init: std.process.Init) !void {
    // Parse demo name from command-line arguments
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    _ = args.next(); // skip executable name
    if (args.next()) |demo_name| {
        current_demo = std.meta.stringToEnum(Demo, demo_name) orelse {
            std.debug.print("unknown demo: {s}\n\navailable demos:\n", .{demo_name});
            inline for (std.meta.fields(Demo)) |field| {
                std.debug.print("  {s}\n", .{field.name});
            }
            return;
        };
    }

    app.init(.{ .on_ready = onReady });

    std.debug.print("running demo: {s}\n", .{@tagName(current_demo)});

    switch (current_demo) {
        // -- Window lifecycle --
        .window_create => {
            window.create(.{ .title = "window_create", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
        },
        .window_destroy => {
            window.create(.{ .title = "window_destroy (disappears in 2s)" });
            window.center();
            window.show();
            // destroy is deferred to onReady
        },
        .window_close => {
            window.create(.{ .title = "window_close (closes in 2s)", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
        },

        // -- Window properties --
        .window_set_title => {
            window.create(.{ .title = "Original Title", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
        },
        .window_set_frame => {
            window.create(.{ .title = "window_set_frame", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
        },
        .window_min_max_size => {
            window.create(.{ .title = "Resize me! min=400x300 max=900x700", .callbacks = .{ .on_close = onClose } });
            window.setMinSize(400, 300);
            window.setMaxSize(900, 700);
            window.center();
            window.show();
        },
        .window_get_frame => {
            window.create(.{ .title = "window_get_frame", .callbacks = .{
                .on_close = onClose,
                .on_resize = onGetFrameUpdate,
                .on_move = onGetFrameMove,
            } });
            window.center();
            window.show();
        },

        // -- Window visibility --
        .window_show_hide => {
            window.create(.{ .title = "window_show_hide", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
        },
        .window_miniaturize => {
            window.create(.{ .title = "window_miniaturize", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
        },
        .window_center => {
            window.create(.{ .title = "window_center", .x = 50, .y = 50, .callbacks = .{ .on_close = onClose } });
            window.show();
        },

        // -- Window style --
        .window_borderless => {
            window.create(.{ .title = "borderless", .style = StyleMask.borderless, .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadHTML(
                \\<html>
                \\<body style="margin:0;padding:40px;background:#1a1a2e;color:#eee;font-family:-apple-system;">
                \\  <h1>Borderless Window</h1>
                \\  <p>This window has no title bar or frame.</p>
                \\</body></html>
            , null);
        },
        .window_set_style_mask => {
            window.create(.{ .title = "window_set_style_mask", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
        },
        // -- macOS only --
        .window_transparent_titlebar => {
            if (!is_macos) {
                std.debug.print("window_transparent_titlebar is macOS only, skipping\n", .{});
                app.terminate();
                return;
            }
            window.create(.{ .title = "transparent titlebar", .style = StyleMask.default | StyleMask.full_size_content_view, .callbacks = .{ .on_close = onClose } });
            window.setTitlebarAppearsTransparent(true);
            window.setTitleVisibility(true);
            window.center();
            window.show();
            // Add colored content so the transparent titlebar effect is visible
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadHTML(
                \\<html>
                \\<body style="margin:0;padding:80px 40px 40px;background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;font-family:-apple-system;">
                \\  <h1>Transparent Titlebar</h1>
                \\  <p>Content extends under the titlebar. Traffic lights float over the gradient.</p>
                \\</body></html>
            , null);
        },
        .window_title_visibility => {
            if (!is_macos) {
                std.debug.print("window_title_visibility is macOS only, skipping\n", .{});
                app.terminate();
                return;
            }
            window.create(.{ .title = "title hidden!", .callbacks = .{ .on_close = onClose } });
            window.setTitleVisibility(true);
            window.center();
            window.show();
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadHTML(
                \\<html>
                \\<body style="margin:0;padding:40px;background:#1a1a2e;color:#eee;font-family:-apple-system;">
                \\  <h1>Title Visibility</h1>
                \\  <p>The title bar text "title hidden!" is set but hidden via setTitleVisibility.</p>
                \\  <p>The titlebar is still there — just no text in it.</p>
                \\</body></html>
            , null);
        },

        // -- Window alpha --
        .window_alpha => {
            window.create(.{ .title = "window_alpha", .style = StyleMask.default | StyleMask.full_size_content_view, .callbacks = .{ .on_close = onClose } });
            window.setOpaque(false);
            if (is_macos) {
                window.setBackgroundColor(objc.msgSend(objc.getClass("NSColor"), objc.sel("clearColor")));
            }
            window.setAlphaValue(0.8);
            window.center();
            window.show();
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadHTML(
                \\<html>
                \\<body style="margin:0;padding:40px;background:rgba(26,26,46,0.9);color:#eee;font-family:-apple-system;">
                \\  <h1>Window Alpha</h1>
                \\  <p>This window is transparent (alpha: 0.8).</p>
                \\  <p>It will animate to 0.3 then back to 1.0.</p>
                \\</body></html>
            , null);
        },

        // -- Window fullscreen --
        .window_toggle_fullscreen => {
            window.create(.{ .title = "window_toggle_fullscreen", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
        },

        // -- Window traffic lights (macOS only) --
        .window_traffic_light_pos => {
            if (!is_macos) {
                std.debug.print("window_traffic_light_pos is macOS only, skipping\n", .{});
                app.terminate();
                return;
            }
            window.create(.{
                .title = "traffic lights moved",
                .style = StyleMask.default | StyleMask.full_size_content_view,
                .callbacks = .{ .on_close = onClose },
            });
            window.setTitlebarAppearsTransparent(true);
            window.setTrafficLightPosition(20, 20);
            window.center();
            window.show();
        },

        // -- Window z-order --
        .window_order_front_back => {
            window.create(.{ .title = "Window 1 (front)", .width = 500, .height = 400, .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();

            window2.create(.{ .title = "Window 2 (back)", .x = 250, .y = 250, .width = 500, .height = 400 });
            window2.show();
            window2.orderBack();
        },

        // -- Window callbacks --
        .window_callbacks => {
            window.create(.{
                .title = "window_callbacks",
                .callbacks = .{
                    .on_close = onClose,
                    .on_resize = onCallbackResize,
                    .on_move = onCallbackMove,
                    .on_focus = onCallbackFocus,
                    .on_blur = onCallbackBlur,
                },
            });
            window.center();
            window.show();
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadHTML(
                \\<html>
                \\<body style="margin:0;padding:20px;background:#1a1a2e;color:#eee;font-family:-apple-system;">
                \\  <h2>Window Callbacks</h2>
                \\  <p>Resize, move, focus, and blur this window.</p>
                \\  <pre id="log" style="background:#111;padding:15px;border-radius:8px;max-height:400px;overflow-y:auto;font-size:14px;"></pre>
                \\  <script>
                \\    var count = 0;
                \\    function log(msg) {
                \\      count++;
                \\      var el = document.getElementById('log');
                \\      el.textContent = count + ': ' + msg + '\n' + el.textContent;
                \\    }
                \\  </script>
                \\</body></html>
            , null);
        },

        // -- WebView lifecycle --
        .webview_create_destroy => {
            window.create(.{ .title = "webview_create_destroy", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadHTML("<h1 style='padding:40px;font-family:-apple-system'>Destroyed in 3s</h1>", null);
        },

        // -- WebView navigation --
        .webview_load_url => {
            window.create(.{ .title = "webview_load_url", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadURL("https://duckduckgo.com");
        },
        .webview_load_html => {
            window.create(.{ .title = "webview_load_html", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadHTML(
                \\<html>
                \\<body style="font-family: -apple-system; padding: 40px; background: #1a1a2e; color: #eee;">
                \\  <h1>Sriracha</h1>
                \\  <p>Loaded from inline HTML via <code>webview.loadHTML()</code></p>
                \\</body></html>
            , null);
        },
        .webview_reload => {
            window.create(.{ .title = "webview_reload", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadURL("https://example.com");
        },
        .webview_back_forward => {
            window.create(.{ .title = "webview_back_forward", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadURL("https://example.com");
        },

        // -- WebView JS --
        .webview_eval_js => {
            window.create(.{ .title = "webview_eval_js", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadHTML("<html><body style='font-family:-apple-system;padding:40px'><h1 id='target'>Waiting...</h1></body></html>", null);
        },
        .webview_js_to_zig => {
            window.create(.{ .title = "webview_js_to_zig", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
            webview.create(.{ .on_script_message = onScriptMessage });
            webview.attachToWindow(&window);
            webview.loadHTML(
                \\<html>
                \\<body style="font-family: -apple-system; padding: 40px;">
                \\  <h1>JS to Zig</h1>
                \\  <button onclick="window.webkit.messageHandlers.sriracha.postMessage('hello from js!')">
                \\    Send Message
                \\  </button>
                \\  <p>Check stderr for output</p>
                \\</body></html>
            , null);
        },

        // -- WebView attach/detach --
        .webview_attach_detach => {
            window.create(.{ .title = "webview_attach_detach", .callbacks = .{ .on_close = onClose } });
            window.center();
            window.show();
            webview.create(.{});
            webview.attachToWindow(&window);
            webview.loadHTML("<h1 style='padding:40px;font-family:-apple-system'>Detaches in 2s, reattaches in 4s</h1>", null);
        },
    }

    app.run();
}

fn onReady() void {
    std.debug.print("app ready\n", .{});

    switch (current_demo) {
        .window_destroy => {
            defer_(2, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("destroying window\n", .{});
                    window.destroy();
                }
            }.f);
        },
        .window_close => {
            defer_(2, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("closing window\n", .{});
                    window.close();
                }
            }.f);
        },
        .window_set_title => {
            defer_(1, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("setting title\n", .{});
                    window.setTitle("New Title!");
                }
            }.f);
        },
        .window_set_frame => {
            defer_(1, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("setting frame (animated)\n", .{});
                    window.setFrame(50, 50, 1200, 800, true);
                }
            }.f);
        },
        .window_get_frame => {
            updateFrameTitle(&window);
        },
        .window_show_hide => {
            defer_(2, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    window.setTitle("Hidden! (reappears in 2s)");
                    window.hide();
                    defer_(2, &struct {
                        fn f2(_: ?*anyopaque) callconv(.c) void {
                            window.setTitle("Shown again!");
                            window.show();
                        }
                    }.f2);
                }
            }.f);
        },
        .window_miniaturize => {
            defer_(1, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("miniaturizing\n", .{});
                    window.miniaturize();
                    defer_(2, &struct {
                        fn f2(_: ?*anyopaque) callconv(.c) void {
                            std.debug.print("deminiaturizing\n", .{});
                            window.deminiaturize();
                        }
                    }.f2);
                }
            }.f);
        },
        .window_center => {
            defer_(1, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("centering\n", .{});
                    window.center();
                }
            }.f);
        },
        .window_set_style_mask => {
            window.setTitle("Goes borderless in 2s...");
            defer_(2, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    window.setStyleMask(StyleMask.borderless);
                    defer_(3, &struct {
                        fn f2(_: ?*anyopaque) callconv(.c) void {
                            window.setStyleMask(StyleMask.default);
                            window.setTitle("Default style restored!");
                        }
                    }.f2);
                }
            }.f);
        },
        .window_alpha => {
            defer_(2, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    window.setAlphaValue(0.3);
                    window.setTitle("alpha: 0.3");
                    defer_(2, &struct {
                        fn f2(_: ?*anyopaque) callconv(.c) void {
                            window.setAlphaValue(1.0);
                            window.setTitle("alpha: 1.0");
                        }
                    }.f2);
                }
            }.f);
        },
        .window_toggle_fullscreen => {
            window.toggleFullScreen();
            defer_(3, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("exiting fullscreen\n", .{});
                    window.toggleFullScreen();
                }
            }.f);
        },
        .window_order_front_back => {
            defer_(2, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("bringing window2 to front\n", .{});
                    window2.orderFront();
                    defer_(2, &struct {
                        fn f2(_: ?*anyopaque) callconv(.c) void {
                            std.debug.print("sending window2 to back\n", .{});
                            window2.orderBack();
                        }
                    }.f2);
                }
            }.f);
        },
        .webview_create_destroy => {
            defer_(3, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("destroying webview\n", .{});
                    webview.destroy();
                }
            }.f);
        },
        .webview_reload => {
            defer_(2, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("reloading\n", .{});
                    webview.reload();
                }
            }.f);
        },
        .webview_back_forward => {
            defer_(2, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("loading second URL\n", .{});
                    webview.loadURL("https://www.iana.org");
                    defer_(2, &struct {
                        fn f2(_: ?*anyopaque) callconv(.c) void {
                            std.debug.print("going back\n", .{});
                            webview.goBack();
                            defer_(2, &struct {
                                fn f3(_: ?*anyopaque) callconv(.c) void {
                                    std.debug.print("going forward\n", .{});
                                    webview.goForward();
                                }
                            }.f3);
                        }
                    }.f2);
                }
            }.f);
        },
        .webview_eval_js => {
            defer_(1, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("evaluating JS\n", .{});
                    webview.evaluateJavaScript("document.getElementById('target').textContent = 'Set from Zig!'");
                    webview.evaluateJavaScript("document.body.style.background = '#1a1a2e'");
                    webview.evaluateJavaScript("document.body.style.color = '#eee'");
                }
            }.f);
        },
        .webview_attach_detach => {
            defer_(2, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    std.debug.print("detaching webview\n", .{});
                    webview.detachFromWindow();
                    defer_(2, &struct {
                        fn f2(_: ?*anyopaque) callconv(.c) void {
                            std.debug.print("reattaching webview\n", .{});
                            webview.attachToWindow(&window);
                        }
                    }.f2);
                }
            }.f);
        },
        else => {},
    }
}

// -- Helpers --

fn defer_(seconds: u64, func: *const fn (?*anyopaque) callconv(.c) void) void {
    if (is_windows) {
        const win_impl = @import("platform/windows/window.zig");
        win_impl.scheduleTimer(@intCast(seconds * 1000), func);
    } else if (is_linux) {
        const gtk = @import("platform/linux/gtk.zig");
        // g_timeout_add takes milliseconds and a GSourceFunc that returns FALSE to run once
        const wrapper = struct {
            fn call(_: gtk.gpointer) callconv(.c) gtk.gboolean {
                func(null);
                return gtk.FALSE; // remove after firing
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

// -- Callbacks --

fn updateFrameTitle(w: *Window) void {
    const f = w.getFrame();
    var buf: [128]u8 = undefined;
    const title = std.fmt.bufPrint(&buf, "frame: {d:.0}x{d:.0} at ({d:.0},{d:.0})", .{
        f.size.width, f.size.height, f.origin.x, f.origin.y,
    }) catch "getFrame error";
    w.setTitle(title);
}

fn onGetFrameUpdate(w: *Window, _: Size) void {
    updateFrameTitle(w);
}

fn onGetFrameMove(w: *Window, _: Point) void {
    updateFrameTitle(w);
}

fn logToWebview(msg: []const u8) void {
    var buf: [256]u8 = undefined;
    const js = std.fmt.bufPrint(&buf, "log('{s}')", .{msg}) catch return;
    webview.evaluateJavaScript(js);
}

fn onCallbackResize(_: *Window, size: Size) void {
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "resize: {d:.0}x{d:.0}", .{ size.width, size.height }) catch return;
    logToWebview(msg);
}

fn onCallbackMove(_: *Window, origin: Point) void {
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "move: ({d:.0},{d:.0})", .{ origin.x, origin.y }) catch return;
    logToWebview(msg);
}

fn onCallbackFocus(_: *Window) void {
    logToWebview("focus");
}

fn onCallbackBlur(_: *Window) void {
    logToWebview("blur");
}

fn onClose(_: *Window) void {
    std.debug.print("on_close\n", .{});
    app.terminate();
}

fn onResize(_: *Window, size: Size) void {
    std.debug.print("on_resize: {d}x{d}\n", .{ size.width, size.height });
}

fn onMove(_: *Window, origin: Point) void {
    std.debug.print("on_move: ({d},{d})\n", .{ origin.x, origin.y });
}

fn onFocus(_: *Window) void {
    std.debug.print("on_focus\n", .{});
}

fn onBlur(_: *Window) void {
    std.debug.print("on_blur\n", .{});
}

fn onScriptMessage(_: *WebView, message: if (is_macos) objc.id else []const u8) void {
    if (is_macos) {
        const body = objc.msgSend(message, objc.sel("body"));
        const utf8 = objc.msgSend(body, objc.sel("UTF8String"));
        if (utf8) |ptr| {
            const str: [*:0]const u8 = @ptrCast(ptr);
            std.debug.print("JS message: {s}\n", .{str});
        }
    } else {
        std.debug.print("JS message: {s}\n", .{message});
    }
}
