const std = @import("std");
const windows = std.os.windows;

// ============================================================
// Re-exported types from std.os.windows
// ============================================================

pub const HWND = windows.HWND;
pub const HINSTANCE = windows.HINSTANCE;
pub const HMODULE = windows.HMODULE;
pub const HBRUSH = windows.HBRUSH;
pub const HCURSOR = windows.HCURSOR;
pub const HICON = windows.HICON;
pub const HMENU = windows.HMENU;
pub const HDC = windows.HDC;
pub const HANDLE = windows.HANDLE;
pub const RECT = windows.RECT;
pub const POINT = windows.POINT;
pub const LPARAM = windows.LPARAM;
pub const WPARAM = windows.WPARAM;
pub const LRESULT = windows.LRESULT;
pub const DWORD = windows.DWORD;
pub const WORD = windows.WORD;
pub const LONG = windows.LONG;
pub const UINT = windows.UINT;
pub const BOOL = windows.BOOL;
pub const ATOM = windows.ATOM;
pub const WCHAR = windows.WCHAR;
pub const LPWSTR = windows.LPWSTR;
pub const LPCWSTR = windows.LPCWSTR;
pub const GUID = windows.GUID;
pub const HRESULT = windows.HRESULT;
pub const LONG_PTR = windows.LONG_PTR;
pub const ULONG_PTR = windows.ULONG_PTR;

pub const TRUE: BOOL = 1;
pub const FALSE: BOOL = 0;
pub const S_OK: HRESULT = 0;

// ============================================================
// Window procedure type
// ============================================================

pub const WNDPROC = *const fn (?HWND, UINT, WPARAM, LPARAM) callconv(.c) LRESULT;

// ============================================================
// Structs not in std.os.windows
// ============================================================

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXW),
    style: UINT = 0,
    lpfnWndProc: ?WNDPROC = null,
    cbClsExtra: c_int = 0,
    cbWndExtra: c_int = 0,
    hInstance: ?HINSTANCE = null,
    hIcon: ?HICON = null,
    hCursor: ?HCURSOR = null,
    hbrBackground: ?HBRUSH = null,
    lpszMenuName: ?LPCWSTR = null,
    lpszClassName: ?LPCWSTR = null,
    hIconSm: ?HICON = null,
};

pub const MSG = extern struct {
    hwnd: ?HWND = null,
    message: UINT = 0,
    wParam: WPARAM = 0,
    lParam: LPARAM = 0,
    time: DWORD = 0,
    pt: POINT = .{ .x = 0, .y = 0 },
};

pub const CREATESTRUCTW = extern struct {
    lpCreateParams: ?*anyopaque,
    hInstance: ?HINSTANCE,
    hMenu: ?HMENU,
    hwndParent: ?HWND,
    cy: c_int,
    cx: c_int,
    y: c_int,
    x: c_int,
    style: LONG,
    lpszName: ?LPCWSTR,
    lpszClass: ?LPCWSTR,
    dwExStyle: DWORD,
};

pub const MINMAXINFO = extern struct {
    ptReserved: POINT,
    ptMaxSize: POINT,
    ptMaxPosition: POINT,
    ptMinTrackSize: POINT,
    ptMaxTrackSize: POINT,
};

// ============================================================
// Window message constants
// ============================================================

pub const WM_CREATE = 0x0001;
pub const WM_DESTROY = 0x0002;
pub const WM_MOVE = 0x0003;
pub const WM_SIZE = 0x0005;
pub const WM_SETFOCUS = 0x0007;
pub const WM_KILLFOCUS = 0x0008;
pub const WM_CLOSE = 0x0010;
pub const WM_ERASEBKGND = 0x0014;
pub const WM_GETMINMAXINFO = 0x0024;
pub const WM_NCCREATE = 0x0081;
pub const WM_TIMER = 0x0113;
pub const WM_USER = 0x0400;

// ============================================================
// Window style constants
// ============================================================

pub const WS_OVERLAPPED: DWORD = 0x00000000;
pub const WS_POPUP: DWORD = 0x80000000;
pub const WS_VISIBLE: DWORD = 0x10000000;
pub const WS_CAPTION: DWORD = 0x00C00000;
pub const WS_SYSMENU: DWORD = 0x00080000;
pub const WS_THICKFRAME: DWORD = 0x00040000;
pub const WS_MINIMIZEBOX: DWORD = 0x00020000;
pub const WS_MAXIMIZEBOX: DWORD = 0x00010000;
pub const WS_CLIPCHILDREN: DWORD = 0x02000000;
pub const WS_OVERLAPPEDWINDOW: DWORD = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

// Extended window styles
pub const WS_EX_LAYERED: DWORD = 0x00080000;
pub const WS_EX_APPWINDOW: DWORD = 0x00040000;

// ============================================================
// ShowWindow constants
// ============================================================

pub const SW_HIDE: c_int = 0;
pub const SW_SHOWNORMAL: c_int = 1;
pub const SW_SHOWMINIMIZED: c_int = 2;
pub const SW_SHOWMAXIMIZED: c_int = 3;
pub const SW_SHOW: c_int = 5;
pub const SW_MINIMIZE: c_int = 6;
pub const SW_RESTORE: c_int = 9;

// ============================================================
// SetWindowPos flags
// ============================================================

pub const SWP_NOSIZE: UINT = 0x0001;
pub const SWP_NOMOVE: UINT = 0x0002;
pub const SWP_NOZORDER: UINT = 0x0004;
pub const SWP_FRAMECHANGED: UINT = 0x0020;
pub const SWP_SHOWWINDOW: UINT = 0x0040;

// SetWindowPos z-order sentinels
pub const HWND_TOP: ?HWND = null;
pub const HWND_BOTTOM: ?HWND = @ptrFromInt(1);
pub const HWND_MESSAGE: ?HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -3))));

// ============================================================
// GetWindowLong / SetWindowLong indices
// ============================================================

pub const GWL_STYLE: c_int = -16;
pub const GWL_EXSTYLE: c_int = -20;
pub const GWLP_USERDATA: c_int = -21;

// ============================================================
// Window class styles
// ============================================================

pub const CS_HREDRAW: UINT = 0x0002;
pub const CS_VREDRAW: UINT = 0x0001;

// ============================================================
// SystemMetrics indices
// ============================================================

pub const SM_CXSCREEN: c_int = 0;
pub const SM_CYSCREEN: c_int = 1;

// ============================================================
// SetLayeredWindowAttributes flags
// ============================================================

pub const LWA_ALPHA: DWORD = 0x00000002;

// ============================================================
// Cursor constants
// ============================================================

pub const IDC_ARROW: LPCWSTR = @ptrFromInt(32512);

// ============================================================
// CW_USEDEFAULT
// ============================================================

pub const CW_USEDEFAULT: c_int = @bitCast(@as(c_uint, 0x80000000));

// ============================================================
// COM constants
// ============================================================

pub const COINIT_APARTMENTTHREADED: DWORD = 0x2;

// ============================================================
// user32 extern functions
// ============================================================

pub extern "user32" fn RegisterClassExW(lpWndClass: *const WNDCLASSEXW) callconv(.c) ATOM;
pub extern "user32" fn CreateWindowExW(
    dwExStyle: DWORD,
    lpClassName: ?LPCWSTR,
    lpWindowName: ?LPCWSTR,
    dwStyle: DWORD,
    X: c_int,
    Y: c_int,
    nWidth: c_int,
    nHeight: c_int,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: ?HINSTANCE,
    lpParam: ?*anyopaque,
) callconv(.c) ?HWND;
pub extern "user32" fn DestroyWindow(hWnd: HWND) callconv(.c) BOOL;
pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: c_int) callconv(.c) BOOL;
pub extern "user32" fn SetWindowTextW(hWnd: HWND, lpString: LPCWSTR) callconv(.c) BOOL;
pub extern "user32" fn MoveWindow(hWnd: HWND, X: c_int, Y: c_int, nWidth: c_int, nHeight: c_int, bRepaint: BOOL) callconv(.c) BOOL;
pub extern "user32" fn SetWindowPos(
    hWnd: HWND,
    hWndInsertAfter: ?HWND,
    X: c_int,
    Y: c_int,
    cx: c_int,
    cy: c_int,
    uFlags: UINT,
) callconv(.c) BOOL;
pub extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: *RECT) callconv(.c) BOOL;
pub extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.c) BOOL;
pub extern "user32" fn SetWindowLongPtrW(hWnd: HWND, nIndex: c_int, dwNewLong: LONG_PTR) callconv(.c) LONG_PTR;
pub extern "user32" fn GetWindowLongPtrW(hWnd: HWND, nIndex: c_int) callconv(.c) LONG_PTR;
pub extern "user32" fn GetMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) callconv(.c) BOOL;
pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.c) BOOL;
pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.c) LRESULT;
pub extern "user32" fn PostQuitMessage(nExitCode: c_int) callconv(.c) void;
pub extern "user32" fn DefWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.c) LRESULT;
pub extern "user32" fn GetSystemMetrics(nIndex: c_int) callconv(.c) c_int;
pub extern "user32" fn SetLayeredWindowAttributes(hWnd: HWND, crKey: DWORD, bAlpha: u8, dwFlags: DWORD) callconv(.c) BOOL;
pub extern "user32" fn GetLayeredWindowAttributes(hWnd: HWND, pcrKey: ?*DWORD, pbAlpha: ?*u8, pdwFlags: ?*DWORD) callconv(.c) BOOL;
pub extern "user32" fn LoadCursorW(hInstance: ?HINSTANCE, lpCursorName: LPCWSTR) callconv(.c) ?HCURSOR;
pub extern "user32" fn PostMessageW(hWnd: ?HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.c) BOOL;
pub extern "user32" fn SetTimer(hWnd: ?HWND, nIDEvent: ULONG_PTR, uElapse: UINT, lpTimerFunc: ?*const anyopaque) callconv(.c) ULONG_PTR;
pub extern "user32" fn KillTimer(hWnd: ?HWND, uIDEvent: ULONG_PTR) callconv(.c) BOOL;
pub extern "user32" fn SetParent(hWndChild: HWND, hWndNewParent: ?HWND) callconv(.c) ?HWND;
pub extern "user32" fn InvalidateRect(hWnd: ?HWND, lpRect: ?*const RECT, bErase: BOOL) callconv(.c) BOOL;
pub extern "user32" fn UpdateWindow(hWnd: HWND) callconv(.c) BOOL;
pub extern "user32" fn SetForegroundWindow(hWnd: HWND) callconv(.c) BOOL;
pub extern "user32" fn IsIconic(hWnd: HWND) callconv(.c) BOOL;

// ============================================================
// gdi32 extern functions
// ============================================================

pub extern "gdi32" fn CreateSolidBrush(color: DWORD) callconv(.c) ?HBRUSH;
pub extern "gdi32" fn DeleteObject(ho: ?*anyopaque) callconv(.c) BOOL;
pub extern "gdi32" fn FillRect(hDC: HDC, lprc: *const RECT, hbr: HBRUSH) callconv(.c) c_int;
pub extern "gdi32" fn GetStockObject(i: c_int) callconv(.c) ?*anyopaque;

// ============================================================
// kernel32 extern functions
// ============================================================

pub extern "kernel32" fn GetModuleHandleW(lpModuleName: ?LPCWSTR) callconv(.c) ?HINSTANCE;
pub extern "kernel32" fn LoadLibraryW(lpLibFileName: LPCWSTR) callconv(.c) ?HMODULE;
pub extern "kernel32" fn GetProcAddress(hModule: HMODULE, lpProcName: [*:0]const u8) callconv(.c) ?*anyopaque;
pub extern "kernel32" fn FreeLibrary(hLibModule: HMODULE) callconv(.c) BOOL;
pub extern "kernel32" fn GetTempPathW(nBufferLength: DWORD, lpBuffer: LPWSTR) callconv(.c) DWORD;
pub extern "kernel32" fn CreateFileW(
    lpFileName: LPCWSTR,
    dwDesiredAccess: DWORD,
    dwShareMode: DWORD,
    lpSecurityAttributes: ?*anyopaque,
    dwCreationDisposition: DWORD,
    dwFlagsAndAttributes: DWORD,
    hTemplateFile: ?HANDLE,
) callconv(.c) HANDLE;
pub extern "kernel32" fn WriteFile(
    hFile: HANDLE,
    lpBuffer: [*]const u8,
    nNumberOfBytesToWrite: DWORD,
    lpNumberOfBytesWritten: ?*DWORD,
    lpOverlapped: ?*anyopaque,
) callconv(.c) BOOL;
pub extern "kernel32" fn CloseHandle(hObject: HANDLE) callconv(.c) BOOL;

pub const GENERIC_READ: DWORD = 0x80000000;
pub const GENERIC_WRITE: DWORD = 0x40000000;
pub const CREATE_ALWAYS: DWORD = 2;
pub const OPEN_EXISTING: DWORD = 3;
pub const FILE_ATTRIBUTE_NORMAL: DWORD = 0x80;
pub const INVALID_HANDLE_VALUE: HANDLE = @ptrFromInt(std.math.maxInt(usize));
pub extern "kernel32" fn GetFileSize(hFile: HANDLE, lpFileSizeHigh: ?*DWORD) callconv(.c) DWORD;

// ============================================================
// ole32 extern functions
// ============================================================

pub extern "ole32" fn CoInitializeEx(pvReserved: ?*anyopaque, dwCoInit: DWORD) callconv(.c) HRESULT;
pub extern "ole32" fn CoUninitialize() callconv(.c) void;

// ============================================================
// UTF-8 <-> UTF-16 helpers
// ============================================================

const allocator = std.heap.page_allocator;

/// Convert a UTF-8 slice to a null-terminated UTF-16LE wide string.
/// Caller must free the returned slice with page_allocator.
pub fn utf8ToWide(str: []const u8) ![:0]const u16 {
    return std.unicode.utf8ToUtf16LeAllocZ(allocator, str);
}

/// Convert a null-terminated UTF-16LE wide string to a UTF-8 slice.
/// Caller must free the returned slice with page_allocator.
pub fn wideToUtf8(wide: LPCWSTR) ![]u8 {
    const ptr: [*]const u16 = @ptrCast(wide);
    var len: usize = 0;
    while (ptr[len] != 0) : (len += 1) {}
    return std.unicode.utf16LeToUtf8Alloc(allocator, ptr[0..len]);
}

// ============================================================
// COM infrastructure
// ============================================================

pub const IUnknownVtbl = extern struct {
    QueryInterface: *const fn (*anyopaque, *const GUID, *?*anyopaque) callconv(.c) HRESULT,
    AddRef: *const fn (*anyopaque) callconv(.c) u32,
    Release: *const fn (*anyopaque) callconv(.c) u32,
};
