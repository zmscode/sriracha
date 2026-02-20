const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });
    const build_demo = b.option(bool, "build_demo", "Build local sriracha demo executable") orelse false;

    const os = target.result.os.tag;

    // ── sriracha library module (importable by consumers) ──

    const sriracha_mod = b.addModule("sriracha", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (os == .macos) {
        const objc_mod = b.addModule("objc", .{
            .root_source_file = b.path("src/platform/macos/objc.zig"),
            .target = target,
        });
        sriracha_mod.addImport("objc", objc_mod);
        sriracha_mod.linkFramework("AppKit", .{});
        sriracha_mod.linkFramework("WebKit", .{});
        sriracha_mod.linkSystemLibrary("objc", .{});
    } else if (os == .windows) {
        sriracha_mod.linkSystemLibrary("user32", .{});
        sriracha_mod.linkSystemLibrary("gdi32", .{});
        sriracha_mod.linkSystemLibrary("kernel32", .{});
        sriracha_mod.linkSystemLibrary("ole32", .{});
    } else if (os == .linux) {
        sriracha_mod.linkSystemLibrary("gtk+-3.0", .{});
        sriracha_mod.linkSystemLibrary("webkit2gtk-4.1", .{});
    }

    if (build_demo) {
        const demo_source = b.path("demo.zig");
        const demo_module = b.createModule(.{
            .root_source_file = demo_source,
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "sriracha", .module = sriracha_mod },
            },
        });

        // The demo uses objc directly in its callbacks on macOS
        if (os == .macos) {
            if (sriracha_mod.import_table.get("objc")) |objc_mod| {
                demo_module.addImport("objc", objc_mod);
            }
        }

        const exe = b.addExecutable(.{
            .name = "sriracha-demo",
            .root_module = demo_module,
        });

        // Windows GUI app — no console window
        if (os == .windows) {
            exe.subsystem = .windows;
        }

        b.installArtifact(exe);

        // -- run step --
        const run_step = b.step("run", "Run the demo");

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
                \\    <string>sriracha-demo</string>
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
            const install_bin = b.addInstallFile(exe.getEmittedBin(), "Sriracha.app/Contents/MacOS/sriracha-demo");

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
    }
}
