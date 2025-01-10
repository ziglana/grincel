const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdk_path = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";

    // Add minimal Metal test executable
    const test_exe = b.addExecutable(.{
        .name = "metal_test",
        .root_source_file = .{ .cwd_relative = "src/metal_test_minimal.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Compile Objective-C sources for test executable
    const test_exe_objc = b.addObject(.{
        .name = "objc_msgSend",
        .target = target,
        .optimize = optimize,
    });
    const objc_files = [_][]const u8{
        "src/objc_msgSend.m",
        "src/objc_msgSend_set_buffer.m",
    };
    const objc_flags = [_][]const u8{
        "-x",
        "objective-c",
        "-fno-objc-arc", // Disable ARC
        "-I" ++ sdk_path ++ "/usr/include",
        "-I" ++ sdk_path ++ "/usr/include/objc",
        "-I" ++ sdk_path ++ "/System/Library/Frameworks/Metal.framework/Headers",
        "-I" ++ sdk_path ++ "/System/Library/Frameworks/Foundation.framework/Headers",
        "-F" ++ sdk_path ++ "/System/Library/Frameworks",
    };
    for (objc_files) |file| {
        test_exe_objc.addCSourceFile(.{
            .file = .{ .cwd_relative = file },
            .flags = &objc_flags,
        });
    }

    // Link with Metal framework for test executable
    if (target.result.os.tag == .macos) {
        test_exe_objc.addFrameworkPath(.{ .cwd_relative = sdk_path ++ "/System/Library/Frameworks" });
        test_exe_objc.linkFramework("Metal");
        test_exe_objc.linkFramework("Foundation");
        test_exe_objc.linkFramework("QuartzCore");
        test_exe_objc.linkSystemLibrary("objc");

        test_exe.addFrameworkPath(.{ .cwd_relative = sdk_path ++ "/System/Library/Frameworks" });
        test_exe.linkSystemLibrary("objc");
        test_exe.linkFramework("Metal");
        test_exe.linkFramework("Foundation");
        test_exe.linkFramework("QuartzCore");
    }

    // Link Objective-C object file with test executable
    test_exe.addObject(test_exe_objc);

    // Create test run step
    const run_test = b.addRunArtifact(test_exe);
    const metal_test_step = b.step("metal-test", "Run minimal Metal test");
    metal_test_step.dependOn(&run_test.step);

    const exe = b.addExecutable(.{
        .name = "grincel",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const metal_module = b.addModule("metal", .{
        .root_source_file = .{ .cwd_relative = "src/metal/metal_compute.zig" },
    });
    exe.root_module.addImport("metal", metal_module);

    // Create output directory
    const mkdir_cmd = b.addSystemCommand(&[_][]const u8{
        "mkdir",
        "-p",
        "zig-out/bin",
    });

    // Compile Metal shader with debug info
    const metal_shader = b.addSystemCommand(&[_][]const u8{
        "xcrun",
        "-sdk",
        "macosx",
        "metal",
        "-g", // Add debug info
        "-Wno-unused-variable", // Suppress unused variable warnings
        "-w", // Disable all warnings
        "-fno-fast-math", // Disable fast math for better precision
        "-c",
        "src/shaders/vanity.metal",
        "-o",
        "vanity.air",
    });
    metal_shader.step.dependOn(&mkdir_cmd.step);

    // Create metallib with debug info
    const metal_lib = b.addSystemCommand(&[_][]const u8{
        "xcrun",
        "-sdk",
        "macosx",
        "metallib",
        "-v", // Verbose output
        "-Werror", // Treat warnings as errors
        "vanity.air",
        "-o",
        "zig-out/bin/default.metallib",
    });
    metal_lib.step.dependOn(&metal_shader.step);

    // Print metallib info for debugging
    const print_metallib = b.addSystemCommand(&[_][]const u8{
        "xcrun",
        "-sdk",
        "macosx",
        "metal-readobj",
        "-all",
        "zig-out/bin/default.metallib",
    });
    print_metallib.step.dependOn(&metal_lib.step);

    // Print directory contents for debugging
    const ls_cmd = b.addSystemCommand(&[_][]const u8{
        "ls",
        "-la",
        "zig-out/bin",
    });
    ls_cmd.step.dependOn(&print_metallib.step);

    // Create a dummy object file
    const dummy_c = b.addSystemCommand(&[_][]const u8{
        "/bin/sh",
        "-c",
        "echo 'const char metallib[] __attribute__((section(\"__DATA,__metallib\"))) = {0};' > zig-out/bin/dummy.c",
    });
    dummy_c.step.dependOn(&ls_cmd.step);

    // Compile dummy object file
    const dummy_o = b.addSystemCommand(&[_][]const u8{
        "cc",
        "-c",
        "-o",
        "zig-out/bin/dummy.o",
        "zig-out/bin/dummy.c",
    });
    dummy_o.step.dependOn(&dummy_c.step);

    // Add dummy object file to executable
    exe.addObjectFile(.{ .cwd_relative = "zig-out/bin/dummy.o" });

    // Compile Objective-C sources separately
    const objc = b.addObject(.{
        .name = "objc_msgSend",
        .target = target,
        .optimize = optimize,
    });
    for (objc_files) |file| {
        objc.addCSourceFile(.{
            .file = .{ .cwd_relative = file },
            .flags = &objc_flags,
        });
    }

    // Link Objective-C object file with executable
    exe.addObject(objc);

    // Link with Metal framework on macOS
    if (target.result.os.tag == .macos) {
        objc.addFrameworkPath(.{ .cwd_relative = sdk_path ++ "/System/Library/Frameworks" });
        objc.linkFramework("Metal");
        objc.linkFramework("Foundation");
        objc.linkFramework("QuartzCore");
        objc.linkSystemLibrary("objc");

        exe.addFrameworkPath(.{ .cwd_relative = sdk_path ++ "/System/Library/Frameworks" });
        exe.linkSystemLibrary("objc");
        exe.linkFramework("Metal");
        exe.linkFramework("Foundation");
        exe.linkFramework("QuartzCore");
    }

    exe.step.dependOn(&dummy_o.step);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Add pattern module
    const pattern_module = b.addModule("pattern", .{
        .root_source_file = .{ .cwd_relative = "src/pattern.zig" },
    });

    // Add pattern tests
    const pattern_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/test/pattern_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    pattern_tests.root_module.addImport("pattern", pattern_module);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/test/metal_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    unit_tests.root_module.addImport("metal", metal_module);

    // Compile Objective-C source separately
    const test_objc = b.addObject(.{
        .name = "objc_msgSend",
        .target = target,
        .optimize = optimize,
    });
    test_objc.addCSourceFile(.{
        .file = .{ .cwd_relative = "src/objc_msgSend.m" },
        .flags = &[_][]const u8{
            "-x",
            "objective-c",
            "-fno-objc-arc", // Disable ARC
            "-I" ++ sdk_path ++ "/usr/include",
            "-I" ++ sdk_path ++ "/usr/include/objc",
            "-I" ++ sdk_path ++ "/System/Library/Frameworks/Metal.framework/Headers",
            "-I" ++ sdk_path ++ "/System/Library/Frameworks/Foundation.framework/Headers",
            "-F" ++ sdk_path ++ "/System/Library/Frameworks",
        },
    });

    // Link Objective-C object file with tests
    unit_tests.addObject(test_objc);

    // Link with Metal framework for tests on macOS
    if (target.result.os.tag == .macos) {
        test_objc.addFrameworkPath(.{ .cwd_relative = sdk_path ++ "/System/Library/Frameworks" });
        test_objc.linkFramework("Metal");
        test_objc.linkFramework("Foundation");
        test_objc.linkFramework("QuartzCore");
        test_objc.linkSystemLibrary("objc");

        unit_tests.addFrameworkPath(.{ .cwd_relative = sdk_path ++ "/System/Library/Frameworks" });
        unit_tests.linkSystemLibrary("objc");
        unit_tests.linkFramework("Metal");
        unit_tests.linkFramework("Foundation");
        unit_tests.linkFramework("QuartzCore");
    }

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const run_pattern_tests = b.addRunArtifact(pattern_tests);
    test_step.dependOn(&run_pattern_tests.step);
}
