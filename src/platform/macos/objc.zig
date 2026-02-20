const std = @import("std");
const c = @cImport({
    @cInclude("objc/runtime.h");
    @cInclude("objc/message.h");
    @cInclude("dispatch/dispatch.h");
});

pub const id = ?*anyopaque;
pub const SEL = ?*anyopaque;
pub const Class = ?*anyopaque;
pub const BOOL = i8;
pub const NSUInteger = u64;
pub const NSInteger = i64;

pub const NSRect = extern struct {
    origin: NSPoint,
    size: NSSize,
};

pub const NSPoint = extern struct {
    x: f64,
    y: f64,
};

pub const NSSize = extern struct {
    width: f64,
    height: f64,
};

pub const objc_msgSend_ptr: *const anyopaque = @ptrCast(@alignCast(&c.objc_msgSend));

pub fn makeRect(x: f64, y: f64, w: f64, h: f64) NSRect {
    return .{
        .origin = .{ .x = x, .y = y },
        .size = .{ .width = w, .height = h },
    };
}

pub inline fn sel(name: [*:0]const u8) SEL {
    return c.sel_registerName(name);
}

pub inline fn getClass(name: [*:0]const u8) id {
    return @as(id, @ptrCast(c.objc_getClass(name)));
}

pub inline fn msgSend(obj: id, selector: SEL) id {
    const f: *const fn (id, SEL) callconv(.c) id = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector);
}

pub inline fn msgSend_id(obj: id, selector: SEL, a0: id) id {
    const f: *const fn (id, SEL, id) callconv(.c) id = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector, a0);
}

pub inline fn msgSend_id_id(obj: id, selector: SEL, a0: id, a1: id) id {
    const f: *const fn (id, SEL, id, id) callconv(.c) id = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector, a0, a1);
}

pub inline fn msgSend_id_id_id(obj: id, selector: SEL, a0: id, a1: id, a2: id) id {
    const f: *const fn (id, SEL, id, id, id) callconv(.c) id = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector, a0, a1, a2);
}

pub inline fn msgSend_bool(obj: id, selector: SEL, val: bool) void {
    const f: *const fn (id, SEL, bool) callconv(.c) void = @ptrCast(@alignCast(&c.objc_msgSend));
    f(obj, selector, val);
}

pub inline fn msgSend_uint(obj: id, selector: SEL, val: NSUInteger) void {
    const f: *const fn (id, SEL, NSUInteger) callconv(.c) void = @ptrCast(@alignCast(&c.objc_msgSend));
    f(obj, selector, val);
}

pub inline fn msgSend_id_void(obj: id, selector: SEL, a0: id) void {
    const f: *const fn (id, SEL, id) callconv(.c) void = @ptrCast(@alignCast(&c.objc_msgSend));
    f(obj, selector, a0);
}

pub inline fn msgSend_sel_void(obj: id, selector: SEL, a0: SEL) void {
    const f: *const fn (id, SEL, SEL) callconv(.c) void = @ptrCast(@alignCast(&c.objc_msgSend));
    f(obj, selector, a0);
}

pub inline fn msgSend_id_id_void(obj: id, selector: SEL, a0: id, a1: id) void {
    const f: *const fn (id, SEL, id, id) callconv(.c) void = @ptrCast(@alignCast(&c.objc_msgSend));
    f(obj, selector, a0, a1);
}

pub inline fn msgSend_rect_uint_uint_bool(obj: id, selector: SEL, rect: NSRect, style: NSUInteger, backing: NSUInteger, defer_: bool) id {
    const f: *const fn (id, SEL, NSRect, NSUInteger, NSUInteger, bool) callconv(.c) id = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector, rect, style, backing, defer_);
}

pub inline fn msgSend_rect_id(obj: id, selector: SEL, rect: NSRect, a0: id) id {
    const f: *const fn (id, SEL, NSRect, id) callconv(.c) id = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector, rect, a0);
}

pub inline fn msgSend_rect(obj: id, selector: SEL, rect: NSRect) id {
    const f: *const fn (id, SEL, NSRect) callconv(.c) id = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector, rect);
}

pub inline fn msgSend_void(obj: id, selector: SEL) void {
    const f: *const fn (id, SEL) callconv(.c) void = @ptrCast(@alignCast(&c.objc_msgSend));
    f(obj, selector);
}

pub inline fn msgSend_bool_ret(obj: id, selector: SEL, val: bool) id {
    const f: *const fn (id, SEL, bool) callconv(.c) id = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector, val);
}

pub inline fn msgSend_stret_rect(obj: id, selector: SEL) NSRect {
    const f: *const fn (id, SEL) callconv(.c) NSRect = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector);
}

pub fn nsString(str: []const u8) id {
    const alloc_obj = msgSend(getClass("NSString"), sel("alloc"));
    const f: *const fn (id, SEL, [*]const u8, NSUInteger, NSUInteger) callconv(.c) id = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(
        alloc_obj,
        sel("initWithBytes:length:encoding:"),
        str.ptr,
        @intCast(str.len),
        4,
    );
}

pub fn nsStringZ(str: [*:0]const u8) id {
    const f: *const fn (id, SEL, [*:0]const u8) callconv(.c) id = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(
        getClass("NSString"),
        sel("stringWithUTF8String:"),
        str,
    );
}

pub fn nsURL(str: []const u8) id {
    return msgSend_id(
        getClass("NSURL"),
        sel("URLWithString:"),
        nsString(str),
    );
}

pub fn allocateClassPair(superclass_name: [*:0]const u8, name: [*:0]const u8) ?*anyopaque {
    const super: ?*c.objc_class = @ptrCast(c.objc_getClass(superclass_name));
    return @ptrCast(c.objc_allocateClassPair(super, name, 0));
}

pub fn addMethod(cls: ?*anyopaque, selector: SEL, imp: *const anyopaque, types: [*:0]const u8) bool {
    return c.class_addMethod(
        @ptrCast(cls),
        @ptrCast(selector),
        @ptrCast(@alignCast(imp)),
        types,
    );
}

pub fn addIvar(cls: ?*anyopaque, name: [*:0]const u8, size: usize, alignment: u8, types: [*:0]const u8) bool {
    return c.class_addIvar(@ptrCast(cls), name, size, alignment, types);
}

pub fn registerClassPair(cls: ?*anyopaque) void {
    c.objc_registerClassPair(@ptrCast(cls));
}

pub fn setIvar(obj: id, name: [*:0]const u8, value: ?*anyopaque) void {
    const ivar = c.class_getInstanceVariable(c.object_getClass(@ptrCast(@alignCast(obj))), name);
    c.object_setIvar(@ptrCast(@alignCast(obj)), ivar, @ptrCast(@alignCast(value)));
}

pub fn getIvar(obj: id, name: [*:0]const u8) ?*anyopaque {
    const ivar = c.class_getInstanceVariable(c.object_getClass(@ptrCast(@alignCast(obj))), name);
    return @ptrCast(c.object_getIvar(@ptrCast(@alignCast(obj)), ivar));
}

pub fn addProtocol(cls: ?*anyopaque, protocol_name: [*:0]const u8) bool {
    const proto = c.objc_getProtocol(protocol_name) orelse return false;
    return c.class_addProtocol(@ptrCast(cls), proto);
}

const dispatch_main_q = @extern(*anyopaque, .{ .name = "_dispatch_main_q" });

pub inline fn msgSend_rect_bool_void(obj: id, selector: SEL, rect: NSRect, display: bool) void {
    const f: *const fn (id, SEL, NSRect, bool) callconv(.c) void = @ptrCast(@alignCast(&c.objc_msgSend));
    f(obj, selector, rect, display);
}

pub inline fn msgSend_rect_bool_bool_void(obj: id, selector: SEL, rect: NSRect, display: bool, animate: bool) void {
    const f: *const fn (id, SEL, NSRect, bool, bool) callconv(.c) void = @ptrCast(@alignCast(&c.objc_msgSend));
    f(obj, selector, rect, display, animate);
}

pub inline fn msgSend_size_void(obj: id, selector: SEL, size: NSSize) void {
    const f: *const fn (id, SEL, NSSize) callconv(.c) void = @ptrCast(@alignCast(&c.objc_msgSend));
    f(obj, selector, size);
}

pub inline fn msgSend_uint_ret(obj: id, selector: SEL) NSUInteger {
    const f: *const fn (id, SEL) callconv(.c) NSUInteger = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector);
}

pub inline fn msgSend_int_id(obj: id, selector: SEL, val: NSUInteger) id {
    const f: *const fn (id, SEL, NSUInteger) callconv(.c) id = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector, val);
}

pub inline fn msgSend_point_void(obj: id, selector: SEL, point: NSPoint) void {
    const f: *const fn (id, SEL, NSPoint) callconv(.c) void = @ptrCast(@alignCast(&c.objc_msgSend));
    f(obj, selector, point);
}

pub inline fn msgSend_f64_void(obj: id, selector: SEL, val: f64) void {
    const f: *const fn (id, SEL, f64) callconv(.c) void = @ptrCast(@alignCast(&c.objc_msgSend));
    f(obj, selector, val);
}

pub inline fn msgSend_f64_ret(obj: id, selector: SEL) f64 {
    const f: *const fn (id, SEL) callconv(.c) f64 = @ptrCast(@alignCast(&c.objc_msgSend));
    return f(obj, selector);
}

pub fn dispatchAsync(context: ?*anyopaque, func: *const fn (?*anyopaque) callconv(.c) void) void {
    c.dispatch_async_f(@ptrCast(dispatch_main_q), context, func);
}
