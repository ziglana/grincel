const std = @import("std");
const metal_framework = @import("../metal_framework.zig");
const types = @import("metal_types.zig");
const MetalError = types.MetalError;
const MetalState = types.MetalState;

pub fn setupCompute(state: *MetalState, pattern_buffer: []const u8, output_buffer: []u8) !void {
    std.debug.print("Metal State: Setting up compute resources...\n", .{});

    // Release old buffers if they exist
    const release_sel = metal_framework.sel_registerName("release");
    if (release_sel != null) {
        if (state.pattern_buffer) |buffer| {
            _ = metal_framework.objc_msgSend_basic(buffer, release_sel);
            state.pattern_buffer = null;
        }
        if (state.output_buffer) |buffer| {
            _ = metal_framework.objc_msgSend_basic(buffer, release_sel);
            state.output_buffer = null;
        }
    }

    // Create pattern buffer with data
    const buffer_sel = metal_framework.sel_registerName("newBufferWithBytes:length:options:") orelse {
        std.debug.print("Failed to get newBufferWithBytes selector\n", .{});
        return MetalError.NoBuffer;
    };

    // Ensure pattern buffer is properly aligned
    const aligned_pattern = try std.heap.page_allocator.alignedAlloc(u8, 16, pattern_buffer.len);
    defer std.heap.page_allocator.free(aligned_pattern);
    @memcpy(aligned_pattern, pattern_buffer);

    std.debug.print("Creating pattern buffer with size: {}, alignment: {}\n", .{ pattern_buffer.len, @alignOf(@TypeOf(aligned_pattern)) });
    const pattern_mtl_buffer = metal_framework.objc_msgSend(
        state.device.?,
        buffer_sel,
        aligned_pattern.ptr,
        pattern_buffer.len,
        metal_framework.MTLResourceStorageModeOptions,
    ) orelse {
        std.debug.print("Failed to create pattern buffer\n", .{});
        return MetalError.NoBuffer;
    };

    // Retain pattern buffer since it's autoreleased
    const retain_sel = metal_framework.sel_registerName("retain");
    if (retain_sel != null) {
        _ = metal_framework.objc_msgSend_basic(pattern_mtl_buffer, retain_sel);
    }

    // Create output buffer with zeroed data
    const aligned_output = try std.heap.page_allocator.alignedAlloc(u8, 16, output_buffer.len);
    defer std.heap.page_allocator.free(aligned_output);
    @memset(aligned_output, 0);

    std.debug.print("Creating output buffer with size: {}, alignment: {}\n", .{ output_buffer.len, @alignOf(@TypeOf(aligned_output)) });
    const output_mtl_buffer = metal_framework.objc_msgSend(
        state.device.?,
        buffer_sel,
        aligned_output.ptr,
        output_buffer.len,
        metal_framework.MTLResourceStorageModeOptions,
    ) orelse {
        std.debug.print("Failed to create output buffer\n", .{});
        return MetalError.NoBuffer;
    };

    // Retain output buffer since it's autoreleased
    if (retain_sel != null) {
        _ = metal_framework.objc_msgSend_basic(output_mtl_buffer, retain_sel);
    }

    // Store buffers in state
    state.pattern_buffer = pattern_mtl_buffer;
    state.output_buffer = output_mtl_buffer;

    // Validate buffers
    try state.validateBuffers();

    std.debug.print("Metal State: Compute resources set up successfully\n", .{});
}

pub fn runCompute(state: *MetalState, grid_size: metal_framework.MTLSize, group_size: metal_framework.MTLSize) !void {
    std.debug.print("Metal State: Running compute...\n", .{});

    // Validate state before running compute
    try state.validate();
    try state.validateBuffers();
    try state.validatePipeline();

    // Create command buffer
    const cmd_buffer_sel = metal_framework.sel_registerName("commandBuffer") orelse {
        std.debug.print("Failed to get commandBuffer selector\n", .{});
        return MetalError.InvalidCommandQueue;
    };

    const command_buffer = metal_framework.objc_msgSend_basic(state.command_queue.?, cmd_buffer_sel) orelse {
        std.debug.print("Failed to create command buffer\n", .{});
        return MetalError.InvalidCommandQueue;
    };

    // Retain command buffer since it's autoreleased
    const retain_sel = metal_framework.sel_registerName("retain");
    if (retain_sel != null) {
        _ = metal_framework.objc_msgSend_basic(command_buffer, retain_sel);
    }
    defer {
        const release_sel = metal_framework.sel_registerName("release");
        if (release_sel != null) {
            _ = metal_framework.objc_msgSend_basic(command_buffer, release_sel);
        }
    }

    // Create compute command encoder
    const encoder_sel = metal_framework.sel_registerName("computeCommandEncoder") orelse {
        std.debug.print("Failed to get computeCommandEncoder selector\n", .{});
        return MetalError.InvalidCommandEncoder;
    };

    const encoder = metal_framework.objc_msgSend_basic(command_buffer, encoder_sel) orelse {
        std.debug.print("Failed to create compute command encoder\n", .{});
        return MetalError.InvalidCommandEncoder;
    };

    // Retain encoder since it's autoreleased
    if (retain_sel != null) {
        _ = metal_framework.objc_msgSend_basic(encoder, retain_sel);
    }
    defer {
        const release_sel = metal_framework.sel_registerName("release");
        if (release_sel != null) {
            _ = metal_framework.objc_msgSend_basic(encoder, release_sel);
        }
    }

    // Set compute pipeline state
    const set_pipeline_sel = metal_framework.sel_registerName("setComputePipelineState:") orelse {
        std.debug.print("Failed to get setComputePipelineState selector\n", .{});
        return MetalError.InvalidPipeline;
    };

    _ = metal_framework.objc_msgSend_set_state(encoder, set_pipeline_sel, state.compute_pipeline.?);

    // Set buffers
    const set_buffer_sel = metal_framework.sel_registerName("setBuffer:offset:atIndex:") orelse {
        std.debug.print("Failed to get setBuffer selector\n", .{});
        return MetalError.InvalidBuffer;
    };

    _ = metal_framework.objc_msgSend_set_buffer(encoder, set_buffer_sel, state.pattern_buffer.?, 0, 0);
    _ = metal_framework.objc_msgSend_set_buffer(encoder, set_buffer_sel, state.output_buffer.?, 0, 1);

    // Dispatch compute
    metal_framework.MetalFramework.dispatch_compute(encoder, grid_size, group_size);

    // End encoding
    const end_encoding_sel = metal_framework.sel_registerName("endEncoding") orelse {
        std.debug.print("Failed to get endEncoding selector\n", .{});
        return MetalError.InvalidCommandEncoder;
    };

    _ = metal_framework.objc_msgSend_basic(encoder, end_encoding_sel);

    // Commit command buffer
    const commit_sel = metal_framework.sel_registerName("commit") orelse {
        std.debug.print("Failed to get commit selector\n", .{});
        return MetalError.InvalidCommandQueue;
    };

    _ = metal_framework.objc_msgSend_basic(command_buffer, commit_sel);

    // Wait for completion
    const wait_sel = metal_framework.sel_registerName("waitUntilCompleted") orelse {
        std.debug.print("Failed to get waitUntilCompleted selector\n", .{});
        return MetalError.InvalidCommandQueue;
    };

    _ = metal_framework.objc_msgSend_basic(command_buffer, wait_sel);

    std.debug.print("Metal State: Compute completed successfully\n", .{});
}

pub fn getResults(state: *MetalState, output_buffer: []u8) !void {
    std.debug.print("Metal State: Getting compute results...\n", .{});

    // Validate state before getting results
    try state.validate();
    try state.validateBuffers();

    const contents_sel = metal_framework.sel_registerName("contents") orelse {
        std.debug.print("Failed to get contents selector\n", .{});
        return MetalError.NoBuffer;
    };

    const output_ptr = metal_framework.objc_msgSend_basic(state.output_buffer.?, contents_sel) orelse {
        std.debug.print("Failed to get output buffer contents\n", .{});
        return MetalError.NoBuffer;
    };

    // Create aligned slice for copying
    const aligned_output = try std.heap.page_allocator.alignedAlloc(u8, 16, output_buffer.len);
    defer std.heap.page_allocator.free(aligned_output);

    // Copy from Metal buffer to aligned slice
    const metal_slice = @as([*]u8, @ptrCast(@alignCast(output_ptr)))[0..output_buffer.len];
    @memcpy(aligned_output, metal_slice);

    // Copy from aligned slice to output buffer
    @memcpy(output_buffer, aligned_output);

    std.debug.print("Metal State: Results retrieved successfully\n", .{});
}
