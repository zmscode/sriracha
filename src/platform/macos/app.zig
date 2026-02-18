const objc = @import("objc");

var on_ready_callback: ?*const fn () void = null;
var delegate_class_registered: bool = false;

fn initDelegateClass() void {
    if (delegate_class_registered) return;

    const cls = objc.allocateClassPair("NSObject", "SrirachaAppDelegate") orelse
        @panic("Failed to create SrirachaAppDelegate class");

    _ = objc.addProtocol(cls, "NSApplicationDelegate");
    _ = objc.addMethod(
        cls,
        objc.sel("applicationDidFinishLaunching:"),
        @ptrCast(&appDidFinishLaunching),
        "v@:@",
    );

    objc.registerClassPair(cls);
    delegate_class_registered = true;
}

fn appDidFinishLaunching(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (on_ready_callback) |cb| cb();
}

pub fn init(opts: struct { on_ready: ?*const fn () void = null }) void {
    initDelegateClass();

    const NSApp = objc.msgSend(objc.getClass("NSApplication"), objc.sel("sharedApplication"));
    objc.msgSend_uint(NSApp, objc.sel("setActivationPolicy:"), 0);

    on_ready_callback = opts.on_ready;

    const delegate_alloc = objc.msgSend(objc.getClass("SrirachaAppDelegate"), objc.sel("alloc"));
    const delegate = objc.msgSend(delegate_alloc, objc.sel("init"));
    objc.msgSend_id_void(NSApp, objc.sel("setDelegate:"), delegate);

    objc.msgSend_bool(NSApp, objc.sel("activateIgnoringOtherApps:"), true);
}

pub fn run() void {
    const NSApp = objc.msgSend(objc.getClass("NSApplication"), objc.sel("sharedApplication"));
    objc.msgSend_void(NSApp, objc.sel("run"));
}

pub fn terminate() void {
    const NSApp = objc.msgSend(objc.getClass("NSApplication"), objc.sel("sharedApplication"));
    objc.msgSend_id_void(NSApp, objc.sel("terminate:"), null);
}
