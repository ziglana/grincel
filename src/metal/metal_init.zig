const std = @import("std");
const metal_framework = @import("../metal_framework.zig");
const types = @import("metal_types.zig");
const MetalError = types.MetalError;
const MetalState = types.MetalState;

pub fn initMetal() !MetalState {
    std.debug.print("Metal State: Creating device...\n", .{});

    var state = MetalState.init();

    // Create Metal device
    const device = metal_framework.MTLCreateSystemDefaultDevice() orelse {
        std.debug.print("Failed to create Metal device\n", .{});
        return MetalError.NoMetalDevice;
    };

    // Verify device capabilities
    const max_threads = metal_framework.MetalFramework.get_max_threads_per_threadgroup(device);
    if (max_threads.width == 0 or max_threads.height == 0 or max_threads.depth == 0) {
        std.debug.print("Invalid max threads per threadgroup: ({}, {}, {})\n", .{
            max_threads.width,
            max_threads.height,
            max_threads.depth,
        });
        return MetalError.InvalidResource;
    }

    const max_memory = metal_framework.MetalFramework.get_max_threadgroup_memory_length(device);
    if (max_memory == 0) {
        std.debug.print("Invalid max threadgroup memory length: {}\n", .{max_memory});
        return MetalError.InvalidResource;
    }

    // Get device name for debugging
    if (metal_framework.MetalFramework.get_device_name(device)) |name| {
        std.debug.print("Metal device name: {s}\n", .{name});
    }

    // Retain device since it's autoreleased
    const retain_sel = metal_framework.sel_registerName("retain");
    if (retain_sel != null) {
        _ = metal_framework.objc_msgSend_basic(device, retain_sel);
        std.debug.print("Metal State: Retained device\n", .{});
    }

    state.device = device;

    // Create command queue
    std.debug.print("Metal State: Creating command queue...\n", .{});
    const cmd_queue_sel = metal_framework.sel_registerName("newCommandQueue") orelse {
        std.debug.print("Failed to get newCommandQueue selector\n", .{});
        return MetalError.NoCommandQueue;
    };

    const command_queue = metal_framework.objc_msgSend_basic(device, cmd_queue_sel) orelse {
        std.debug.print("Failed to create command queue\n", .{});
        return MetalError.NoCommandQueue;
    };

    // Verify command queue is valid
    const device_sel = metal_framework.sel_registerName("device") orelse {
        std.debug.print("Failed to get device selector\n", .{});
        return MetalError.InvalidCommandQueue;
    };
    const queue_device = metal_framework.objc_msgSend_basic(command_queue, device_sel);
    if (queue_device == null or queue_device != device) {
        std.debug.print("Command queue device mismatch\n", .{});
        return MetalError.InvalidCommandQueue;
    }

    // Retain command queue since it's autoreleased
    if (retain_sel != null) {
        _ = metal_framework.objc_msgSend_basic(command_queue, retain_sel);
        std.debug.print("Metal State: Retained command queue\n", .{});
    }

    state.command_queue = command_queue;

    std.debug.print("Metal State: Initialization complete\n", .{});
    return state;
}

pub fn deinitMetal(state: *MetalState) void {
    state.deinit();
}
