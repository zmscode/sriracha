const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const os = target.result.os.tag;

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/sriracha.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (os == .macos) {
        const objc_mod = b.addModule("objc", .{
            .root_source_file = b.path("src/platform/macos/objc.zig"),
            .target = target,
        });
        root_module.addImport("objc", objc_mod);
        root_module.linkFramework("AppKit", .{});
        root_module.linkFramework("WebKit", .{});
        root_module.linkSystemLibrary("objc", .{});
    } else if (os == .windows) {
        root_module.linkSystemLibrary("user32", .{});
        root_module.linkSystemLibrary("gdi32", .{});
        root_module.linkSystemLibrary("kernel32", .{});
        root_module.linkSystemLibrary("ole32", .{});
    } else if (os == .linux) {
        root_module.linkSystemLibrary("gtk+-3.0", .{});
        root_module.linkSystemLibrary("webkit2gtk-4.1", .{});
    }

    const exe = b.addExecutable(.{
        .name = "sriracha",
        .root_module = root_module,
    });

    // Windows GUI app — no console window
    if (os == .windows) {
        exe.subsystem = .windows;
    }

    b.installArtifact(exe);

    // Windows: WebView2Loader.dll is embedded in the exe via @embedFile

    // -- run step --
    const run_step = b.step("run", "Run the app");

    if (os == .macos) {
        // macOS: create .app bundle and launch via open -W
        const wf = b.addWriteFiles();
        const plist = wf.add("Info.plist",
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\<plist version="1.0">
            \\<dict>
            \\    <key>CFBundleName</key>
            \\    <string>Sriracha</string>
            \\    <key>CFBundleIdentifier</key>
            \\    <string>com.sriracha.app</string>
            \\    <key>CFBundleExecutable</key>
            \\    <string>sriracha</string>
            \\    <key>CFBundlePackageType</key>
            \\    <string>APPL</string>
            \\    <key>CFBundleVersion</key>
            \\    <string>1.0</string>
            \\    <key>NSHighResolutionCapable</key>
            \\    <true/>
            \\</dict>
            \\</plist>
            \\
        );
        const install_plist = b.addInstallFile(plist, "Sriracha.app/Contents/Info.plist");
        const install_bin = b.addInstallFile(exe.getEmittedBin(), "Sriracha.app/Contents/MacOS/sriracha");

        const bundle_step = b.step("bundle", "Create Sriracha.app bundle");
        bundle_step.dependOn(&install_plist.step);
        bundle_step.dependOn(&install_bin.step);

        const bundle_path = b.getInstallPath(.prefix, "Sriracha.app");
        const run_cmd = b.addSystemCommand(&.{ "open", "-W", bundle_path, "--args" });
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        run_cmd.step.dependOn(&install_plist.step);
        run_cmd.step.dependOn(&install_bin.step);
        run_step.dependOn(&run_cmd.step);
    } else {
        // Windows / Linux: run the executable directly
        const run_cmd = b.addRunArtifact(exe);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        run_step.dependOn(&run_cmd.step);
    }

    // -- tests --
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
