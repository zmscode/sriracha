const win32 = @import("win32.zig");

var on_ready_callback: ?*const fn () void = null;
var h_instance: ?win32.HINSTANCE = null;

pub fn init(opts: struct { on_ready: ?*const fn () void = null }) void {
    h_instance = win32.GetModuleHandleW(null);
    on_ready_callback = opts.on_ready;

    _ = win32.CoInitializeEx(null, win32.COINIT_APARTMENTTHREADED);
}

pub fn run() void {
    if (on_ready_callback) |cb| cb();

    var msg: win32.MSG = .{};
    while (win32.GetMessageW(&msg, null, 0, 0) != 0) {
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }

    win32.CoUninitialize();
}

pub fn terminate() void {
    win32.PostQuitMessage(0);
}

pub fn getInstance() ?win32.HINSTANCE {
    return h_instance;
}
