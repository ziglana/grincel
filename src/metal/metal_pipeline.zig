const std = @import("std");
const metal_framework = @import("../metal_framework.zig");
const types = @import("metal_types.zig");
const MetalError = types.MetalError;
const MetalState = types.MetalState;

pub fn createPipeline(state: *MetalState, function_name: [*:0]const u8) !void {
    std.debug.print("Creating pipeline for shader: {s}\n", .{function_name});

    // Create library from metallib file
    const library = try loadMetalLibrary(state);
    if (library == null) {
        std.debug.print("Failed to create library\n", .{});
        return MetalError.NoLibrary;
    }

    // Release old library if it exists
    if (state.library) |old_library| {
        const release_sel = metal_framework.sel_registerName("release");
        if (release_sel != null) {
            _ = metal_framework.objc_msgSend_basic(old_library, release_sel);
        }
    }

    state.library = library;

    // Verify library is valid
    const library_device = metal_framework.MTLFunction_getDevice(library);
    if (library_device == null or library_device != state.device) {
        std.debug.print("Library device mismatch\n", .{});
        return MetalError.InvalidLibrary;
    }

    // Get compute function
    const function = try getComputeFunction(state, function_name);
    if (function == null) {
        std.debug.print("Failed to get compute function\n", .{});
        return MetalError.NoFunction;
    }

    // Verify function is valid
    const function_device = metal_framework.MTLFunction_getDevice(function);
    if (function_device == null or function_device != state.device) {
        std.debug.print("Function device mismatch\n", .{});
        return MetalError.InvalidFunction;
    }

    const function_name_str = metal_framework.MTLFunction_getName(function);
    if (function_name_str == null or !std.mem.eql(u8, std.mem.span(function_name_str.?), std.mem.span(function_name))) {
        std.debug.print("Function name mismatch\n", .{});
        return MetalError.InvalidFunction;
    }

    // Create compute pipeline state
    const pipeline = try createPipelineState(state, function);
    if (pipeline == null) {
        std.debug.print("Failed to create pipeline state\n", .{});
        return MetalError.NoPipelineState;
    }

    // Release old pipeline state if it exists
    if (state.compute_pipeline) |old_pipeline| {
        const release_sel = metal_framework.sel_registerName("release");
        if (release_sel != null) {
            _ = metal_framework.objc_msgSend_basic(old_pipeline, release_sel);
        }
    }

    state.compute_pipeline = pipeline;
    std.debug.print("Pipeline created successfully\n", .{});
}

fn loadMetalLibrary(state: *const MetalState) !?*anyopaque {
    std.debug.print("Metal State: Checking for metallib...\n", .{});

    // Try to find metallib in different locations
    const metallib_paths = [_][]const u8{
        "test.metallib", // Try our test shader first
        "vanity.metallib", // Then try vanity shader
        "zig-out/bin/default.metallib",
        "default.metallib",
        "../zig-out/bin/default.metallib",
    };

    var metallib_path: []const u8 = undefined;
    var found = false;
    for (metallib_paths) |path| {
        std.debug.print("Metal State: Checking for metallib at '{s}'...\n", .{path});
        if (std.fs.cwd().access(path, .{})) |_| {
            metallib_path = path;
            found = true;
            break;
        } else |_| {
            continue;
        }
    }

    if (!found) {
        std.debug.print("Metal State: Could not find metallib in any location\n", .{});
        return MetalError.NoLibrary;
    }

    // Get absolute path for metallib
    std.debug.print("Metal State: Getting absolute path for metallib...\n", .{});
    const abs_path = try std.fs.cwd().realpathAlloc(std.heap.page_allocator, metallib_path);
    defer std.heap.page_allocator.free(abs_path);
    std.debug.print("Metal State: Absolute path: {s}\n", .{abs_path});

    // Create a null-terminated copy of the path
    var path_buf: [std.fs.MAX_PATH_BYTES:0]u8 = undefined;
    const path_z = try std.fmt.bufPrintZ(&path_buf, "{s}", .{abs_path});

    // Create URL for metallib
    const url_class = metal_framework.objc_getClass("NSURL") orelse return MetalError.NoLibrary;
    const file_url_sel = metal_framework.sel_registerName("fileURLWithPath:isDirectory:") orelse return MetalError.NoLibrary;
    const path_str = metal_framework.NSString_stringWithUTF8String(path_z.ptr) orelse return MetalError.NoLibrary;
    const url = metal_framework.objc_msgSend_url(url_class, file_url_sel, path_str, false) orelse return MetalError.NoLibrary;
    defer _ = metal_framework.objc_msgSend_basic(url, metal_framework.sel_registerName("release"));
    defer _ = metal_framework.objc_msgSend_basic(path_str, metal_framework.sel_registerName("release"));

    // Load library from URL
    var error_ptr: ?*anyopaque = null;
    const new_library_sel = metal_framework.sel_registerName("newLibraryWithURL:error:") orelse return MetalError.NoLibrary;
    const library = metal_framework.objc_msgSend_library_url(state.device.?, new_library_sel, url, &error_ptr) orelse {
        if (error_ptr) |err| {
            const desc = metal_framework.objc_msgSend_get_description(err);
            if (desc) |d| {
                std.debug.print("Metal State: Error loading library: {s}\n", .{d});
            }
            _ = metal_framework.objc_msgSend_basic(err, metal_framework.sel_registerName("release"));
        }
        std.debug.print("Metal State: Failed to load library\n", .{});
        return MetalError.NoLibrary;
    };

    // Retain the library since it's autoreleased
    const retain_sel = metal_framework.sel_registerName("retain");
    if (retain_sel != null) {
        _ = metal_framework.objc_msgSend_basic(library, retain_sel);
        std.debug.print("Metal State: Retained library\n", .{});
    }

    std.debug.print("Metal State: Library loaded successfully\n", .{});
    return library;
}

fn getComputeFunction(state: *const MetalState, function_name: [*:0]const u8) !?*anyopaque {
    std.debug.print("Metal State: Getting function '{s}'...\n", .{function_name});

    const function_sel = metal_framework.sel_registerName("newFunctionWithName:") orelse {
        std.debug.print("Failed to get newFunctionWithName selector\n", .{});
        return MetalError.NoFunction;
    };

    const name_str = metal_framework.NSString_stringWithUTF8String(function_name) orelse {
        std.debug.print("Failed to create function name string\n", .{});
        return MetalError.NoFunction;
    };
    defer _ = metal_framework.objc_msgSend_basic(name_str, metal_framework.sel_registerName("release"));

    const function = metal_framework.objc_msgSend_nsstr(
        state.library.?,
        function_sel,
        name_str,
    ) orelse {
        std.debug.print("Failed to get compute function\n", .{});
        return MetalError.NoFunction;
    };

    // Retain function since it's autoreleased
    const retain_sel = metal_framework.sel_registerName("retain");
    if (retain_sel != null) {
        _ = metal_framework.objc_msgSend_basic(function, retain_sel);
        std.debug.print("Metal State: Retained function\n", .{});
    }

    std.debug.print("Metal State: Successfully got function from library\n", .{});
    return function;
}

fn createPipelineState(state: *const MetalState, function: ?*anyopaque) !?*anyopaque {
    std.debug.print("Metal State: Creating pipeline state...\n", .{});

    const pipeline_sel = metal_framework.sel_registerName("newComputePipelineStateWithFunction:error:") orelse {
        std.debug.print("Failed to get newComputePipelineStateWithFunction selector\n", .{});
        return MetalError.NoPipelineState;
    };

    var err_ptr: ?*anyopaque = null;
    const pipeline = metal_framework.objc_msgSend_id_error(
        state.device.?,
        pipeline_sel,
        function,
        &err_ptr,
    ) orelse {
        std.debug.print("Failed to create compute pipeline state\n", .{});
        if (err_ptr != null) {
            const desc = metal_framework.objc_msgSend_get_description(err_ptr);
            if (desc) |d| {
                std.debug.print("Error: {s}\n", .{d});
            }
            _ = metal_framework.objc_msgSend_basic(err_ptr, metal_framework.sel_registerName("release"));
        }
        return MetalError.NoPipelineState;
    };

    // Retain pipeline since it's autoreleased
    const retain_sel = metal_framework.sel_registerName("retain");
    if (retain_sel != null) {
        _ = metal_framework.objc_msgSend_basic(pipeline, retain_sel);
        std.debug.print("Metal State: Retained pipeline\n", .{});
    }

    std.debug.print("Metal State: Successfully created compute pipeline state\n", .{});
    return pipeline;
}
