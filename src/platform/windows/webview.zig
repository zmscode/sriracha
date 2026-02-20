const std = @import("std");
const win32 = @import("win32.zig");
const window_mod = @import("window.zig");
const Window = window_mod.Window;

const allocator = std.heap.page_allocator;

// ============================================================
// WebView2 COM interface vtable definitions
// ============================================================

const EventRegistrationToken = extern struct { value: i64 };

const E_NOINTERFACE: win32.HRESULT = @bitCast(@as(u32, 0x80004002));

const IID_IUnknown = win32.GUID{
    .Data1 = 0x00000000,
    .Data2 = 0x0000,
    .Data3 = 0x0000,
    .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 },
};

const IID_EnvironmentCompletedHandler = win32.GUID{
    .Data1 = 0x4E8A3389,
    .Data2 = 0xC9D8,
    .Data3 = 0x4BD2,
    .Data4 = .{ 0xB6, 0xB5, 0x12, 0x4F, 0xEE, 0x6C, 0xC1, 0x4D },
};

const IID_ControllerCompletedHandler = win32.GUID{
    .Data1 = 0x6C4819F3,
    .Data2 = 0xC9B7,
    .Data3 = 0x4260,
    .Data4 = .{ 0x81, 0x27, 0xC9, 0xF5, 0xBD, 0xE7, 0xF6, 0x8C },
};

const IID_WebMessageReceivedHandler = win32.GUID{
    .Data1 = 0x57213F19,
    .Data2 = 0x00E6,
    .Data3 = 0x49FA,
    .Data4 = .{ 0x8E, 0x07, 0x89, 0x8E, 0xA0, 0x1E, 0xCB, 0xD2 },
};

fn guidsEqual(a: *const win32.GUID, b: *const win32.GUID) bool {
    return a.Data1 == b.Data1 and a.Data2 == b.Data2 and a.Data3 == b.Data3 and
        std.mem.eql(u8, &a.Data4, &b.Data4);
}

// ICoreWebView2Environment vtable
// IUnknown (3) + CreateCoreWebView2Controller, CreateWebResourceResponse
const ICoreWebView2EnvironmentVtbl = extern struct {
    // IUnknown
    QueryInterface: *const fn (*anyopaque, *const win32.GUID, *?*anyopaque) callconv(.c) win32.HRESULT,
    AddRef: *const fn (*anyopaque) callconv(.c) u32,
    Release: *const fn (*anyopaque) callconv(.c) u32,
    // ICoreWebView2Environment
    CreateCoreWebView2Controller: *const fn (*anyopaque, ?win32.HWND, *anyopaque) callconv(.c) win32.HRESULT,
    CreateWebResourceResponse: *const anyopaque,
};

const ICoreWebView2Environment = extern struct {
    lpVtbl: *const ICoreWebView2EnvironmentVtbl,
};

// ICoreWebView2Controller vtable — verified against webview2-sys Rust crate
// IUnknown (3) + 23 methods
const ICoreWebView2ControllerVtbl = extern struct {
    // IUnknown
    QueryInterface: *const fn (*anyopaque, *const win32.GUID, *?*anyopaque) callconv(.c) win32.HRESULT,
    AddRef: *const fn (*anyopaque) callconv(.c) u32,
    Release: *const fn (*anyopaque) callconv(.c) u32,
    // ICoreWebView2Controller (exact order from WebView2.h)
    get_IsVisible: *const fn (*anyopaque, *win32.BOOL) callconv(.c) win32.HRESULT, // 1
    put_IsVisible: *const fn (*anyopaque, win32.BOOL) callconv(.c) win32.HRESULT, // 2
    get_Bounds: *const fn (*anyopaque, *win32.RECT) callconv(.c) win32.HRESULT, // 3
    put_Bounds: *const fn (*anyopaque, win32.RECT) callconv(.c) win32.HRESULT, // 4
    get_ZoomFactor: *const anyopaque, // 5
    put_ZoomFactor: *const anyopaque, // 6
    add_ZoomFactorChanged: *const anyopaque, // 7
    remove_ZoomFactorChanged: *const anyopaque, // 8
    SetBoundsAndZoomFactor: *const anyopaque, // 9
    MoveFocus: *const anyopaque, // 10
    add_MoveFocusRequested: *const anyopaque, // 11
    remove_MoveFocusRequested: *const anyopaque, // 12
    add_GotFocus: *const anyopaque, // 13
    remove_GotFocus: *const anyopaque, // 14
    add_LostFocus: *const anyopaque, // 15
    remove_LostFocus: *const anyopaque, // 16
    add_AcceleratorKeyPressed: *const anyopaque, // 17
    remove_AcceleratorKeyPressed: *const anyopaque, // 18
    get_ParentWindow: *const fn (*anyopaque, *?win32.HWND) callconv(.c) win32.HRESULT, // 19
    put_ParentWindow: *const fn (*anyopaque, ?win32.HWND) callconv(.c) win32.HRESULT, // 20
    NotifyParentWindowPositionChanged: *const fn (*anyopaque) callconv(.c) win32.HRESULT, // 21
    Close: *const fn (*anyopaque) callconv(.c) win32.HRESULT, // 22
    get_CoreWebView2: *const fn (*anyopaque, *?*anyopaque) callconv(.c) win32.HRESULT, // 23
};

const ICoreWebView2Controller = extern struct {
    lpVtbl: *const ICoreWebView2ControllerVtbl,
};

// ICoreWebView2 vtable — verified against webview2-sys Rust crate
// IUnknown (3) + 58 methods
const ICoreWebView2Vtbl = extern struct {
    // IUnknown
    QueryInterface: *const fn (*anyopaque, *const win32.GUID, *?*anyopaque) callconv(.c) win32.HRESULT,
    AddRef: *const fn (*anyopaque) callconv(.c) u32,
    Release: *const fn (*anyopaque) callconv(.c) u32,
    // ICoreWebView2 (exact vtable order from WebView2.h / webview2-sys)
    get_Settings: *const anyopaque, // 1
    get_Source: *const anyopaque, // 2
    Navigate: *const fn (*anyopaque, win32.LPCWSTR) callconv(.c) win32.HRESULT, // 3
    NavigateToString: *const fn (*anyopaque, win32.LPCWSTR) callconv(.c) win32.HRESULT, // 4
    add_NavigationStarting: *const anyopaque, // 5
    remove_NavigationStarting: *const anyopaque, // 6
    add_ContentLoading: *const anyopaque, // 7
    remove_ContentLoading: *const anyopaque, // 8
    add_SourceChanged: *const anyopaque, // 9
    remove_SourceChanged: *const anyopaque, // 10
    add_HistoryChanged: *const anyopaque, // 11
    remove_HistoryChanged: *const anyopaque, // 12
    add_NavigationCompleted: *const anyopaque, // 13
    remove_NavigationCompleted: *const anyopaque, // 14
    add_FrameNavigationStarting: *const anyopaque, // 15
    remove_FrameNavigationStarting: *const anyopaque, // 16
    add_FrameNavigationCompleted: *const anyopaque, // 17
    remove_FrameNavigationCompleted: *const anyopaque, // 18
    add_ScriptDialogOpening: *const anyopaque, // 19
    remove_ScriptDialogOpening: *const anyopaque, // 20
    add_PermissionRequested: *const anyopaque, // 21
    remove_PermissionRequested: *const anyopaque, // 22
    add_ProcessFailed: *const anyopaque, // 23
    remove_ProcessFailed: *const anyopaque, // 24
    AddScriptToExecuteOnDocumentCreated: *const fn (*anyopaque, win32.LPCWSTR, ?*anyopaque) callconv(.c) win32.HRESULT, // 25
    RemoveScriptToExecuteOnDocumentCreated: *const anyopaque, // 26
    ExecuteScript: *const fn (*anyopaque, win32.LPCWSTR, ?*anyopaque) callconv(.c) win32.HRESULT, // 27
    CapturePreview: *const anyopaque, // 28
    Reload: *const fn (*anyopaque) callconv(.c) win32.HRESULT, // 29
    PostWebMessageAsJson: *const fn (*anyopaque, win32.LPCWSTR) callconv(.c) win32.HRESULT, // 30
    PostWebMessageAsString: *const fn (*anyopaque, win32.LPCWSTR) callconv(.c) win32.HRESULT, // 31
    add_WebMessageReceived: *const fn (*anyopaque, *anyopaque, *EventRegistrationToken) callconv(.c) win32.HRESULT, // 32
    remove_WebMessageReceived: *const fn (*anyopaque, EventRegistrationToken) callconv(.c) win32.HRESULT, // 33
    CallDevToolsProtocolMethod: *const anyopaque, // 34
    get_BrowserProcessId: *const anyopaque, // 35
    get_CanGoBack: *const anyopaque, // 36
    get_CanGoForward: *const anyopaque, // 37
    GoBack: *const fn (*anyopaque) callconv(.c) win32.HRESULT, // 38
    GoForward: *const fn (*anyopaque) callconv(.c) win32.HRESULT, // 39
    GetDevToolsProtocolEventReceiver: *const anyopaque, // 40
    Stop: *const fn (*anyopaque) callconv(.c) win32.HRESULT, // 41
    add_NewWindowRequested: *const anyopaque, // 42
    remove_NewWindowRequested: *const anyopaque, // 43
    add_DocumentTitleChanged: *const anyopaque, // 44
    remove_DocumentTitleChanged: *const anyopaque, // 45
    get_DocumentTitle: *const anyopaque, // 46
    AddHostObjectToScript: *const anyopaque, // 47
    RemoveHostObjectFromScript: *const anyopaque, // 48
    OpenDevToolsWindow: *const anyopaque, // 49
    add_ContainsFullScreenElementChanged: *const anyopaque, // 50
    remove_ContainsFullScreenElementChanged: *const anyopaque, // 51
    get_ContainsFullScreenElement: *const anyopaque, // 52
    add_WebResourceRequested: *const anyopaque, // 53
    remove_WebResourceRequested: *const anyopaque, // 54
    AddWebResourceRequestedFilter: *const anyopaque, // 55
    RemoveWebResourceRequestedFilter: *const anyopaque, // 56
    add_WindowCloseRequested: *const anyopaque, // 57
    remove_WindowCloseRequested: *const anyopaque, // 58
};

const ICoreWebView2 = extern struct {
    lpVtbl: *const ICoreWebView2Vtbl,
};

// ICoreWebView2WebMessageReceivedEventArgs vtable
// IUnknown + get_Source, get_WebMessageAsJson, TryGetWebMessageAsString
const ICoreWebView2WebMessageReceivedEventArgsVtbl = extern struct {
    QueryInterface: *const fn (*anyopaque, *const win32.GUID, *?*anyopaque) callconv(.c) win32.HRESULT,
    AddRef: *const fn (*anyopaque) callconv(.c) u32,
    Release: *const fn (*anyopaque) callconv(.c) u32,
    get_Source: *const anyopaque,
    get_WebMessageAsJson: *const fn (*anyopaque, *?win32.LPWSTR) callconv(.c) win32.HRESULT,
    TryGetWebMessageAsString: *const fn (*anyopaque, *?win32.LPWSTR) callconv(.c) win32.HRESULT,
};

// ============================================================
// COM callback handler: Environment creation completed
// ============================================================

const EnvironmentCompletedHandler = extern struct {
    vtbl: *const VTable,
    ref_count: u32 = 1,
    webview: *WebView,

    const VTable = extern struct {
        QueryInterface: *const fn (*anyopaque, *const win32.GUID, *?*anyopaque) callconv(.c) win32.HRESULT,
        AddRef: *const fn (*anyopaque) callconv(.c) u32,
        Release: *const fn (*anyopaque) callconv(.c) u32,
        Invoke: *const fn (*anyopaque, win32.HRESULT, ?*anyopaque) callconv(.c) win32.HRESULT,
    };

    const vtbl_impl = VTable{
        .QueryInterface = &queryInterface,
        .AddRef = &addRef,
        .Release = &release,
        .Invoke = &invoke,
    };

    fn queryInterface(self_raw: *anyopaque, riid: *const win32.GUID, ppv: *?*anyopaque) callconv(.c) win32.HRESULT {
        if (guidsEqual(riid, &IID_IUnknown) or guidsEqual(riid, &IID_EnvironmentCompletedHandler)) {
            ppv.* = self_raw;
            const self: *EnvironmentCompletedHandler = @ptrCast(@alignCast(self_raw));
            self.ref_count += 1;
            return win32.S_OK;
        }
        ppv.* = null;
        return E_NOINTERFACE;
    }

    fn addRef(self_raw: *anyopaque) callconv(.c) u32 {
        const self: *EnvironmentCompletedHandler = @ptrCast(@alignCast(self_raw));
        self.ref_count += 1;
        return self.ref_count;
    }

    fn release(self_raw: *anyopaque) callconv(.c) u32 {
        const self: *EnvironmentCompletedHandler = @ptrCast(@alignCast(self_raw));
        self.ref_count -= 1;
        return self.ref_count;
    }

    fn invoke(self_raw: *anyopaque, error_code: win32.HRESULT, env_raw: ?*anyopaque) callconv(.c) win32.HRESULT {
        const self: *EnvironmentCompletedHandler = @ptrCast(@alignCast(self_raw));
        if (error_code < 0) {
            std.debug.print("WebView2 environment creation failed: 0x{x}\n", .{@as(u32, @bitCast(error_code))});
            return win32.S_OK;
        }
        if (env_raw) |env| {
            // AddRef the environment since we're storing it
            const env_typed: *const ICoreWebView2Environment = @ptrCast(@alignCast(env));
            _ = env_typed.lpVtbl.AddRef(env);
            self.webview.environment = env;
            if (self.webview.widget) |widget| {
                self.webview.createController(widget);
            }
        }
        return win32.S_OK;
    }
};

// ============================================================
// COM callback handler: Controller creation completed
// ============================================================

const ControllerCompletedHandler = extern struct {
    vtbl: *const VTable,
    ref_count: u32 = 1,
    webview: *WebView,

    const VTable = extern struct {
        QueryInterface: *const fn (*anyopaque, *const win32.GUID, *?*anyopaque) callconv(.c) win32.HRESULT,
        AddRef: *const fn (*anyopaque) callconv(.c) u32,
        Release: *const fn (*anyopaque) callconv(.c) u32,
        Invoke: *const fn (*anyopaque, win32.HRESULT, ?*anyopaque) callconv(.c) win32.HRESULT,
    };

    const vtbl_impl = VTable{
        .QueryInterface = &queryInterface,
        .AddRef = &addRef,
        .Release = &release,
        .Invoke = &invoke,
    };

    fn queryInterface(self_raw: *anyopaque, riid: *const win32.GUID, ppv: *?*anyopaque) callconv(.c) win32.HRESULT {
        if (guidsEqual(riid, &IID_IUnknown) or guidsEqual(riid, &IID_ControllerCompletedHandler)) {
            ppv.* = self_raw;
            const self: *ControllerCompletedHandler = @ptrCast(@alignCast(self_raw));
            self.ref_count += 1;
            return win32.S_OK;
        }
        ppv.* = null;
        return E_NOINTERFACE;
    }

    fn addRef(self_raw: *anyopaque) callconv(.c) u32 {
        const self: *ControllerCompletedHandler = @ptrCast(@alignCast(self_raw));
        self.ref_count += 1;
        return self.ref_count;
    }

    fn release(self_raw: *anyopaque) callconv(.c) u32 {
        const self: *ControllerCompletedHandler = @ptrCast(@alignCast(self_raw));
        self.ref_count -= 1;
        return self.ref_count;
    }

    fn invoke(self_raw: *anyopaque, error_code: win32.HRESULT, ctrl_raw: ?*anyopaque) callconv(.c) win32.HRESULT {
        const self: *ControllerCompletedHandler = @ptrCast(@alignCast(self_raw));
        const wv = self.webview;

        if (error_code < 0) {
            std.debug.print("WebView2 controller creation failed: 0x{x}\n", .{@as(u32, @bitCast(error_code))});
            return win32.S_OK;
        }

        if (ctrl_raw) |ctrl| {
            const ctrl_typed: *const ICoreWebView2Controller = @ptrCast(@alignCast(ctrl));
            // AddRef since we're storing it
            _ = ctrl_typed.lpVtbl.AddRef(ctrl);
            wv.controller = ctrl;

            // Get the core webview
            var core: ?*anyopaque = null;
            _ = ctrl_typed.lpVtbl.get_CoreWebView2(ctrl, &core);
            if (core) |c| {
                // AddRef the core webview since we're storing it
                const core_typed: *const ICoreWebView2 = @ptrCast(@alignCast(c));
                _ = core_typed.lpVtbl.AddRef(c);
            }
            wv.core_webview = core;

            // Resize to fill the widget
            if (wv.widget) |widget| {
                var rc: win32.RECT = undefined;
                _ = win32.GetClientRect(widget, &rc);
                _ = ctrl_typed.lpVtbl.put_Bounds(ctrl, rc);
            }

            // Show the webview
            _ = ctrl_typed.lpVtbl.put_IsVisible(ctrl, win32.TRUE);

            // Register for web message events and inject compat script
            if (core) |c| {
                wv.setupMessageHandler(c);
                wv.injectCompatibilityScript(c);
            }

            // Mark as ready and flush pending operations
            wv.is_ready = true;
            wv.flushPending();
        }
        return win32.S_OK;
    }
};

// ============================================================
// COM callback handler: WebMessageReceived
// ============================================================

const WebMessageReceivedHandler = extern struct {
    vtbl: *const VTable,
    ref_count: u32 = 1,
    webview: *WebView,

    const VTable = extern struct {
        QueryInterface: *const fn (*anyopaque, *const win32.GUID, *?*anyopaque) callconv(.c) win32.HRESULT,
        AddRef: *const fn (*anyopaque) callconv(.c) u32,
        Release: *const fn (*anyopaque) callconv(.c) u32,
        Invoke: *const fn (*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.c) win32.HRESULT,
    };

    const vtbl_impl = VTable{
        .QueryInterface = &queryInterface,
        .AddRef = &addRef,
        .Release = &release,
        .Invoke = &invoke,
    };

    fn queryInterface(self_raw: *anyopaque, riid: *const win32.GUID, ppv: *?*anyopaque) callconv(.c) win32.HRESULT {
        if (guidsEqual(riid, &IID_IUnknown) or guidsEqual(riid, &IID_WebMessageReceivedHandler)) {
            ppv.* = self_raw;
            const self: *WebMessageReceivedHandler = @ptrCast(@alignCast(self_raw));
            self.ref_count += 1;
            return win32.S_OK;
        }
        ppv.* = null;
        return E_NOINTERFACE;
    }

    fn addRef(self_raw: *anyopaque) callconv(.c) u32 {
        const self: *WebMessageReceivedHandler = @ptrCast(@alignCast(self_raw));
        self.ref_count += 1;
        return self.ref_count;
    }

    fn release(self_raw: *anyopaque) callconv(.c) u32 {
        const self: *WebMessageReceivedHandler = @ptrCast(@alignCast(self_raw));
        self.ref_count -= 1;
        return self.ref_count;
    }

    fn invoke(self_raw: *anyopaque, _: ?*anyopaque, args_raw: ?*anyopaque) callconv(.c) win32.HRESULT {
        const self: *WebMessageReceivedHandler = @ptrCast(@alignCast(self_raw));
        if (self.webview.on_script_message) |cb| {
            if (args_raw) |args| {
                // Read the vtbl pointer from the COM object
                const vtbl_ptr: *const *const ICoreWebView2WebMessageReceivedEventArgsVtbl = @ptrCast(@alignCast(args));
                var wide_msg: ?win32.LPWSTR = null;
                _ = vtbl_ptr.*.TryGetWebMessageAsString(args, &wide_msg);
                if (wide_msg) |msg| {
                    defer win32.CoTaskMemFree(@ptrCast(msg));
                    const utf8 = win32.wideToUtf8(msg) catch return win32.S_OK;
                    defer allocator.free(utf8);
                    cb(self.webview, utf8);
                }
            }
        }
        return win32.S_OK;
    }
};

// ============================================================
// WebView2 loader
// ============================================================

// Embedded DLL bytes (WebView2Loader.dll compiled into the exe)
const embedded_dll = @embedFile("WebView2Loader.dll");

// CreateCoreWebView2EnvironmentWithOptions from WebView2Loader.dll
const CreateEnvironmentFn = *const fn (
    ?win32.LPCWSTR, // browserExecutableFolder
    ?win32.LPCWSTR, // userDataFolder
    ?*anyopaque, // ICoreWebView2EnvironmentOptions
    *anyopaque, // completion handler
) callconv(.c) win32.HRESULT;

/// Write the embedded DLL to a temp file and return a handle to the loaded library.
/// Skips extraction if the file already exists with the correct size.
fn loadEmbeddedDll() ?win32.HMODULE {
    // Build temp path: %TEMP%\SrirachaWebView2Loader.dll
    var tmp_buf: [512]u16 = @splat(0);
    const tmp_len = win32.GetTempPathW(tmp_buf.len, @ptrCast(&tmp_buf));
    if (tmp_len == 0 or tmp_len >= tmp_buf.len - 30) return null;

    const suffix = std.unicode.utf8ToUtf16LeStringLiteral("SrirachaWebView2Loader.dll");
    const suffix_with_null = suffix[0 .. suffix.len + 1]; // include null terminator
    @memcpy(tmp_buf[tmp_len..][0..suffix_with_null.len], suffix_with_null);

    const dll_path: win32.LPCWSTR = @ptrCast(&tmp_buf);

    // Check if the DLL already exists with the correct size
    const existing = win32.CreateFileW(
        dll_path,
        win32.GENERIC_READ,
        0,
        null,
        win32.OPEN_EXISTING,
        win32.FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (existing != win32.INVALID_HANDLE_VALUE) {
        const size = win32.GetFileSize(existing, null);
        _ = win32.CloseHandle(existing);
        if (size == embedded_dll.len) {
            return win32.LoadLibraryW(dll_path);
        }
    }

    // Extract embedded DLL to temp file
    const file = win32.CreateFileW(
        dll_path,
        win32.GENERIC_WRITE,
        0,
        null,
        win32.CREATE_ALWAYS,
        win32.FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (file == win32.INVALID_HANDLE_VALUE) return null;

    var written: win32.DWORD = 0;
    const ok = win32.WriteFile(file, embedded_dll.ptr, embedded_dll.len, &written, null);
    _ = win32.CloseHandle(file);

    if (ok == 0 or written != embedded_dll.len) return null;

    return win32.LoadLibraryW(dll_path);
}

/// Create the WebView2 environment by loading WebView2Loader.dll.
/// Tries the embedded DLL first, falls back to loading from the exe directory.
fn getUserDataFolder() ?win32.LPCWSTR {
    const S = struct {
        var buf: [512]u16 = @splat(0);
        var ready: bool = false;
    };
    if (S.ready) return @ptrCast(&S.buf);

    const tmp_len = win32.GetTempPathW(S.buf.len, @ptrCast(&S.buf));
    if (tmp_len == 0 or tmp_len >= S.buf.len - 20) return null;

    const suffix = std.unicode.utf8ToUtf16LeStringLiteral("SrirachaWebView2");
    const suffix_with_null = suffix[0 .. suffix.len + 1];
    @memcpy(S.buf[tmp_len..][0..suffix_with_null.len], suffix_with_null);
    S.ready = true;
    return @ptrCast(&S.buf);
}

fn createWebView2Environment(handler: *anyopaque) bool {
    const loader = loadEmbeddedDll() orelse
        win32.LoadLibraryW(std.unicode.utf8ToUtf16LeStringLiteral("WebView2Loader.dll"));

    if (loader) |lib| {
        const proc = win32.GetProcAddress(lib, "CreateCoreWebView2EnvironmentWithOptions");
        if (proc) |p| {
            const createEnv: CreateEnvironmentFn = @ptrCast(p);
            const user_data = getUserDataFolder();
            const hr = createEnv(null, user_data, null, handler);
            if (hr >= 0) return true;
            std.debug.print("WebView2 CreateEnvironment failed: 0x{x}\n", .{@as(u32, @bitCast(hr))});
        } else {
            std.debug.print("WebView2Loader.dll missing CreateCoreWebView2EnvironmentWithOptions\n", .{});
        }
    } else {
        std.debug.print("WebView2Loader.dll not found\n", .{});
    }
    return false;
}

// ============================================================
// WebView struct
// ============================================================

const WS_CHILD: win32.DWORD = 0x40000000;
const WS_VISIBLE: win32.DWORD = 0x10000000;
const WS_CLIPCHILDREN: win32.DWORD = 0x02000000;
const WS_EX_CONTROLPARENT: win32.DWORD = 0x00010000;

var widget_class_registered: bool = false;
const WIDGET_CLASS_NAME = std.unicode.utf8ToUtf16LeStringLiteral("SrirachaWebViewWidget");

fn ensureWidgetClassRegistered() void {
    if (widget_class_registered) return;
    const wc = win32.WNDCLASSEXW{
        .lpfnWndProc = &widgetWndProc,
        .hInstance = @import("app.zig").getInstance(),
        .lpszClassName = WIDGET_CLASS_NAME,
    };
    _ = win32.RegisterClassExW(&wc);
    widget_class_registered = true;
}

fn widgetWndProc(hwnd: ?win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) callconv(.c) win32.LRESULT {
    const h = hwnd orelse return 0;
    if (msg == win32.WM_SIZE) {
        // Resize the WebView2 controller to fill this widget
        const ptr = win32.GetWindowLongPtrW(h, win32.GWLP_USERDATA);
        if (ptr != 0) {
            const wv: *WebView = @ptrFromInt(@as(usize, @bitCast(ptr)));
            if (wv.controller) |ctrl| {
                const ctrl_typed: *const ICoreWebView2Controller = @ptrCast(@alignCast(ctrl));
                var rc: win32.RECT = undefined;
                _ = win32.GetClientRect(h, &rc);
                _ = ctrl_typed.lpVtbl.put_Bounds(ctrl, rc);
                _ = ctrl_typed.lpVtbl.NotifyParentWindowPositionChanged(ctrl);
            }
        }
        return 0;
    }
    return win32.DefWindowProcW(h, msg, wparam, lparam);
}

pub const WebView = struct {
    // COM objects
    environment: ?*anyopaque = null,
    controller: ?*anyopaque = null,
    core_webview: ?*anyopaque = null,

    // Child widget HWND that hosts the WebView2 rendering surface
    widget: ?win32.HWND = null,

    // Zig state
    window: ?*Window = null,
    handler_name: []const u8 = "sriracha",
    on_script_message: ?*const fn (*WebView, []const u8) void = null,
    is_ready: bool = false,
    controller_requested: bool = false,

    // Pending operations before webview is ready
    pending_url: ?[]u8 = null,
    pending_html: ?[]u8 = null,

    // COM handler instances (must be stable in memory since COM holds pointers)
    env_handler: EnvironmentCompletedHandler = undefined,
    controller_handler: ControllerCompletedHandler = undefined,
    msg_handler: WebMessageReceivedHandler = undefined,
    msg_token: EventRegistrationToken = .{ .value = 0 },

    pub const CreateOptions = struct {
        handler_name: []const u8 = "sriracha",
        on_script_message: ?*const fn (*WebView, []const u8) void = null,
    };

    pub fn create(self: *WebView, opts: CreateOptions) void {
        self.handler_name = opts.handler_name;
        self.on_script_message = opts.on_script_message;
        self.clearPending();

        // Initialize COM callback handlers
        self.env_handler = .{
            .vtbl = &EnvironmentCompletedHandler.vtbl_impl,
            .ref_count = 1,
            .webview = self,
        };
        self.controller_handler = .{
            .vtbl = &ControllerCompletedHandler.vtbl_impl,
            .ref_count = 1,
            .webview = self,
        };
        self.msg_handler = .{
            .vtbl = &WebMessageReceivedHandler.vtbl_impl,
            .ref_count = 1,
            .webview = self,
        };

        // Environment creation is deferred until attachToWindow is called,
        // because WebView2 requires a message loop to be active.
    }

    /// Attach the webview to a window. On Windows, this is required before
    /// the webview can render — WebView2's controller needs an HWND.
    /// If the environment is already created, this triggers controller creation.
    /// If not, the controller will be created when the environment callback fires.
    var pending_init: ?*WebView = null;

    pub fn attachToWindow(self: *WebView, win: *Window) void {
        self.window = win;

        // Create a child widget window to host the WebView2 rendering surface
        if (self.widget == null) {
            if (win.native) |parent_hwnd| {
                ensureWidgetClassRegistered();
                var rc: win32.RECT = undefined;
                _ = win32.GetClientRect(parent_hwnd, &rc);
                self.widget = win32.CreateWindowExW(
                    WS_EX_CONTROLPARENT,
                    WIDGET_CLASS_NAME,
                    null,
                    WS_CHILD | WS_CLIPCHILDREN,
                    0,
                    0,
                    0,
                    0,
                    parent_hwnd,
                    null,
                    @import("app.zig").getInstance(),
                    null,
                );
                // Store WebView pointer in widget's user data for WM_SIZE handling
                if (self.widget) |w| {
                    _ = win32.SetWindowLongPtrW(w, win32.GWLP_USERDATA, @as(win32.LONG_PTR, @bitCast(@intFromPtr(self))));
                    // Resize to fill parent and show
                    _ = win32.MoveWindow(w, 0, 0, rc.right, rc.bottom, win32.TRUE);
                    _ = win32.ShowWindow(w, win32.SW_SHOW);
                }
                // Also set as content_view so the main window resizes it on WM_SIZE
                win.content_view = self.widget;
            }
        }

        if (self.controller) |ctrl| {
            // Controller already exists — just reparent
            const ctrl_typed: *const ICoreWebView2Controller = @ptrCast(@alignCast(ctrl));
            if (self.widget) |w| {
                _ = ctrl_typed.lpVtbl.put_ParentWindow(ctrl, w);
                var rc: win32.RECT = undefined;
                _ = win32.GetClientRect(w, &rc);
                _ = ctrl_typed.lpVtbl.put_Bounds(ctrl, rc);
                _ = ctrl_typed.lpVtbl.put_IsVisible(ctrl, win32.TRUE);
            }
        } else if (self.environment == null) {
            // Defer environment creation using a WM_TIMER on a message-only window.
            // Avoids TIMERPROC callback pointers which trigger AV heuristics.
            pending_init = self;
            @import("window.zig").scheduleTimer(1, &struct {
                fn f(_: ?*anyopaque) callconv(.c) void {
                    if (pending_init) |wv| {
                        pending_init = null;
                        _ = createWebView2Environment(@ptrCast(&wv.env_handler));
                    }
                }
            }.f);
        } else if (self.environment != null and !self.controller_requested) {
            if (self.widget) |w| {
                self.createController(w);
            }
        }
    }

    pub fn loadURL(self: *WebView, url: []const u8) void {
        if (self.core_webview) |wv| {
            const wide = win32.utf8ToWide(url) catch return;
            defer allocator.free(wide);
            const typed: *const ICoreWebView2 = @ptrCast(@alignCast(wv));
            _ = typed.lpVtbl.Navigate(wv, wide.ptr);
        } else {
            self.setPendingUrl(url);
        }
    }

    pub fn loadHTML(self: *WebView, html: []const u8, _: ?[]const u8) void {
        if (self.core_webview) |wv| {
            const wide = win32.utf8ToWide(html) catch return;
            defer allocator.free(wide);
            const typed: *const ICoreWebView2 = @ptrCast(@alignCast(wv));
            _ = typed.lpVtbl.NavigateToString(wv, wide.ptr);
        } else {
            self.setPendingHtml(html);
        }
    }

    pub fn reload(self: *WebView) void {
        if (self.core_webview) |wv| {
            const typed: *const ICoreWebView2 = @ptrCast(@alignCast(wv));
            _ = typed.lpVtbl.Reload(wv);
        }
    }

    pub fn goBack(self: *WebView) void {
        if (self.core_webview) |wv| {
            const typed: *const ICoreWebView2 = @ptrCast(@alignCast(wv));
            _ = typed.lpVtbl.GoBack(wv);
        }
    }

    pub fn goForward(self: *WebView) void {
        if (self.core_webview) |wv| {
            const typed: *const ICoreWebView2 = @ptrCast(@alignCast(wv));
            _ = typed.lpVtbl.GoForward(wv);
        }
    }

    pub fn evaluateJavaScript(self: *WebView, js: []const u8) void {
        if (self.core_webview) |wv| {
            const wide = win32.utf8ToWide(js) catch return;
            defer allocator.free(wide);
            const typed: *const ICoreWebView2 = @ptrCast(@alignCast(wv));
            _ = typed.lpVtbl.ExecuteScript(wv, wide.ptr, null);
        }
    }

    pub fn detachFromWindow(self: *WebView) void {
        if (self.controller) |ctrl| {
            const ctrl_typed: *const ICoreWebView2Controller = @ptrCast(@alignCast(ctrl));
            _ = ctrl_typed.lpVtbl.put_IsVisible(ctrl, win32.FALSE);
        }
        self.window = null;
    }

    pub fn destroy(self: *WebView) void {
        self.detachFromWindow();
        self.clearPending();

        if (self.core_webview) |wv| {
            const typed: *const ICoreWebView2 = @ptrCast(@alignCast(wv));
            _ = typed.lpVtbl.remove_WebMessageReceived(wv, self.msg_token);
        }

        if (self.controller) |ctrl| {
            const ctrl_typed: *const ICoreWebView2Controller = @ptrCast(@alignCast(ctrl));
            _ = ctrl_typed.lpVtbl.Close(ctrl);
            _ = ctrl_typed.lpVtbl.Release(ctrl);
        }

        if (self.core_webview) |wv| {
            const typed: *const ICoreWebView2 = @ptrCast(@alignCast(wv));
            _ = typed.lpVtbl.Release(wv);
        }

        if (self.environment) |env| {
            const typed: *const ICoreWebView2Environment = @ptrCast(@alignCast(env));
            _ = typed.lpVtbl.Release(env);
        }

        self.controller = null;
        self.core_webview = null;
        self.environment = null;
        self.is_ready = false;
        self.controller_requested = false;
    }

    // --------------------------------------------------------
    // Internal helpers
    // --------------------------------------------------------

    fn createController(self: *WebView, hwnd: win32.HWND) void {
        if (self.controller_requested) return;
        self.controller_requested = true;
        const env = self.environment orelse return;
        const env_typed: *const ICoreWebView2Environment = @ptrCast(@alignCast(env));
        _ = env_typed.lpVtbl.CreateCoreWebView2Controller(env, hwnd, @ptrCast(&self.controller_handler));
    }

    fn setupMessageHandler(self: *WebView, core: *anyopaque) void {
        const typed: *const ICoreWebView2 = @ptrCast(@alignCast(core));
        _ = typed.lpVtbl.add_WebMessageReceived(core, @ptrCast(&self.msg_handler), &self.msg_token);
    }

    fn injectCompatibilityScript(self: *WebView, core: *anyopaque) void {
        // Inject a shim so macOS-style postMessage calls work:
        // window.webkit.messageHandlers.<name>.postMessage(msg)
        // maps to window.chrome.webview.postMessage(msg)
        var buf: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\window.webkit = window.webkit || {{}};
            \\window.webkit.messageHandlers = window.webkit.messageHandlers || {{}};
            \\window.webkit.messageHandlers.{s} = {{
            \\  postMessage: function(msg) {{ window.chrome.webview.postMessage(msg); }}
            \\}};
        , .{self.handler_name}) catch return;

        const wide = win32.utf8ToWide(js) catch return;
        defer allocator.free(wide);
        const typed: *const ICoreWebView2 = @ptrCast(@alignCast(core));
        _ = typed.lpVtbl.AddScriptToExecuteOnDocumentCreated(core, wide.ptr, null);
    }

    fn flushPending(self: *WebView) void {
        if (self.pending_url) |url| {
            self.loadURL(url);
            allocator.free(url);
            self.pending_url = null;
        }
        if (self.pending_html) |html| {
            self.loadHTML(html, null);
            allocator.free(html);
            self.pending_html = null;
        }
    }

    fn setPendingUrl(self: *WebView, url: []const u8) void {
        if (self.pending_html) |html| {
            allocator.free(html);
            self.pending_html = null;
        }
        if (self.pending_url) |old| allocator.free(old);
        self.pending_url = allocator.dupe(u8, url) catch null;
    }

    fn setPendingHtml(self: *WebView, html: []const u8) void {
        if (self.pending_url) |url| {
            allocator.free(url);
            self.pending_url = null;
        }
        if (self.pending_html) |old| allocator.free(old);
        self.pending_html = allocator.dupe(u8, html) catch null;
    }

    fn clearPending(self: *WebView) void {
        if (self.pending_url) |url| {
            allocator.free(url);
            self.pending_url = null;
        }
        if (self.pending_html) |html| {
            allocator.free(html);
            self.pending_html = null;
        }
    }
};
