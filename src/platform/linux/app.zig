const gtk = @import("gtk.zig");

var on_ready_callback: ?*const fn () void = null;

pub fn init(opts: struct { on_ready: ?*const fn () void = null }) void {
    gtk.gtk_init(null, null);
    on_ready_callback = opts.on_ready;
}

fn onIdleReady(_: gtk.gpointer) callconv(.c) gtk.gboolean {
    if (on_ready_callback) |cb| cb();
    return gtk.FALSE; // remove idle source after first call
}

pub fn run() void {
    // Schedule on_ready to fire once the GTK main loop is active
    if (on_ready_callback != null) {
        _ = gtk.g_idle_add(@ptrCast(&onIdleReady), null);
    }
    gtk.gtk_main();
}

pub fn terminate() void {
    gtk.gtk_main_quit();
}
