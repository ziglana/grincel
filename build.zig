const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .aarch64,
            .os_tag = .macos,
            .abi = .none,
            .cpu_model = .baseline,
            .os_version_min = .{
                .semver = .{ .major = 13, .minor = 0, .patch = 0 },
            },
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    // Add spice dependency
    const spice_dep = b.dependency("spice", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "grincel",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add spice module
    exe.root_module.addImport("spice", spice_dep.module("spice"));

    // System libraries
    exe.linkSystemLibrary("c");
    if (target.result.os.tag == .macos) {
        exe.addSystemIncludePath(.{ .cwd_relative = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include" });
        exe.addLibraryPath(.{ .cwd_relative = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib" });
        exe.linkSystemLibrary("objc");
    }

    // Platform specific libraries
    if (target.result.os.tag == .macos) {
        const sdk_path = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";
        // Add framework paths
        exe.addFrameworkPath(.{ .cwd_relative = sdk_path ++ "/System/Library/Frameworks" });
        exe.addFrameworkPath(.{ .cwd_relative = "/System/Library/Frameworks" });

        // Link required frameworks and libraries
        exe.linkFramework("Metal");
        exe.linkFramework("Foundation");
        exe.linkFramework("QuartzCore");
        exe.linkFramework("CoreFoundation");

        // Set runtime paths
        exe.addRPath(.{ .cwd_relative = "/System/Library/Frameworks/Metal.framework/Metal" });

        // Create lib directory
        const make_lib_dir = b.addSystemCommand(&[_][]const u8{
            "mkdir",
            "-p",
            "zig-out/lib",
        });

        // Compile Metal shader
        const metal_compile = b.addSystemCommand(&[_][]const u8{
            "/usr/bin/xcrun",
            "-sdk",
            "macosx",
            "metal",
            "-ffast-math",
            "-I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include",
            "-c",
            "src/shaders/vanity.metal",
            "-o",
            "zig-out/lib/vanity.metallib",
        });
        metal_compile.step.dependOn(&make_lib_dir.step);
        b.getInstallStep().dependOn(&metal_compile.step);
    } else {
        exe.linkSystemLibrary("vulkan");
    }

    exe.addIncludePath(.{ .cwd_relative = "deps/ed25519/src" });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the vanity address generator");
    run_step.dependOn(&run_cmd.step);
}
