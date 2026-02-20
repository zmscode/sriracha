const std = @import("std");
const win32 = @import("win32.zig");

var on_ready_callback: ?*const fn () void = null;
var h_instance: ?win32.HINSTANCE = null;
var com_initialized: bool = false;

pub fn init(opts: struct { on_ready: ?*const fn () void = null }) void {
    h_instance = win32.GetModuleHandleW(null);
    on_ready_callback = opts.on_ready;

    const hr = win32.CoInitializeEx(null, win32.COINIT_APARTMENTTHREADED);
    if (hr >= 0) {
        com_initialized = true;
    } else {
        com_initialized = false;
        std.debug.print("CoInitializeEx failed: 0x{x}\n", .{@as(u32, @bitCast(hr))});
    }
}

pub fn run() void {
    if (on_ready_callback) |cb| cb();

    var msg: win32.MSG = .{};
    while (true) {
        const gm = win32.GetMessageW(&msg, null, 0, 0);
        if (gm == -1) {
            std.debug.print("GetMessageW failed\n", .{});
            break;
        }
        if (gm == 0) break;
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }

    if (com_initialized) {
        win32.CoUninitialize();
        com_initialized = false;
    }
}

pub fn terminate() void {
    win32.PostQuitMessage(0);
}

pub fn getInstance() ?win32.HINSTANCE {
    return h_instance;
}
