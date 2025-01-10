const std = @import("std");

pub const Metal = struct {
    device: *anyopaque,
    command_queue: *anyopaque,
    pipeline_state: *anyopaque,
    state: *MetalState,

    pub fn deinit(self: *Metal, allocator: std.mem.Allocator) void {
        if (self.state) |state| {
            state.deinit();
            allocator.destroy(state) catch |err| {
                std.debug.print("Failed to destroy MetalState: {}\n", .{err});
            };
            self.state = null;
        }
        self.device = null;
        self.command_queue = null;
        self.pipeline_state = null;
    }

    pub fn init(allocator: std.mem.Allocator) !Metal {
        const state = try allocator.create(MetalState);
        state.* = MetalState{
            .device = undefined,
            .command_queue = undefined,
            .compute_pipeline = undefined,
            .pattern_buffer = null,
            .output_buffer = null,
            .library = undefined,
        };

        return Metal{
            .device = undefined,
            .command_queue = undefined,
            .pipeline_state = undefined,
            .state = state,
        };
    }

    pub fn createComputePipeline(self: *Metal) !void {
        _ = self; // TODO: Implement pipeline creation
        return error.Unimplemented;
    }
};
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
    std.debug.print("Creating pattern buffer with size: {} bytes\n", .{pattern_buffer.len});
    if (pattern_buffer.len % 16 != 0) {
        std.debug.print("Pattern buffer size {} is not 16-byte aligned\n", .{pattern_buffer.len});
        return MetalError.InvalidBufferSize;
    }
    const pattern_mtl_buffer = metal_framework.objc_msgSend_buffer(
        state.device.?,
        metal_framework.sel_registerName("newBufferWithLength:options:") orelse return MetalError.NoBuffer,
        pattern_buffer.len,
        metal_framework.MTLResourceStorageModeShared,
    ) orelse {
        std.debug.print("Failed to create pattern buffer\n", .{});
        return MetalError.NoBuffer;
    };

    // Copy pattern data to buffer
    const contents_sel = metal_framework.sel_registerName("contents") orelse {
        std.debug.print("Failed to get contents selector\n", .{});
        return MetalError.NoBuffer;
    };

    const pattern_ptr = metal_framework.objc_msgSend_basic(pattern_mtl_buffer, contents_sel) orelse {
        std.debug.print("Failed to get pattern buffer contents\n", .{});
        return MetalError.NoBuffer;
    };

    const pattern_slice = @as([*]u8, @ptrCast(@alignCast(pattern_ptr)))[0..pattern_buffer.len];
    @memcpy(pattern_slice, pattern_buffer);

    // Create output buffer and initialize with zeros
    std.debug.print("Creating output buffer with size: {} bytes\n", .{output_buffer.len});
    if (output_buffer.len % 16 != 0) {
        std.debug.print("Output buffer size {} is not 16-byte aligned\n", .{output_buffer.len});
        return MetalError.InvalidBufferSize;
    }
    const output_mtl_buffer = metal_framework.objc_msgSend_buffer(
        state.device.?,
        metal_framework.sel_registerName("newBufferWithLength:options:") orelse return MetalError.NoBuffer,
        output_buffer.len,
        metal_framework.MTLResourceStorageModeShared,
    ) orelse {
        std.debug.print("Failed to create output buffer\n", .{});
        return MetalError.NoBuffer;
    };

    // Initialize output buffer with zeros
    const output_contents_sel = metal_framework.sel_registerName("contents") orelse {
        std.debug.print("Failed to get contents selector\n", .{});
        return MetalError.NoBuffer;
    };

    const output_ptr = metal_framework.objc_msgSend_basic(output_mtl_buffer, output_contents_sel) orelse {
        std.debug.print("Failed to get output buffer contents\n", .{});
        return MetalError.NoBuffer;
    };

    const output_slice = @as([*]u8, @ptrCast(@alignCast(output_ptr)))[0..output_buffer.len];
    @memset(output_slice, 0);

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
        std.debug.print("Retained compute encoder\n", .{});
    }
    defer {
        const release_sel = metal_framework.sel_registerName("release");
        if (release_sel != null) {
            _ = metal_framework.objc_msgSend_basic(encoder, release_sel);
            std.debug.print("Released compute encoder\n", .{});
        }
    }

    // Set compute pipeline state
    const set_pipeline_sel = metal_framework.sel_registerName("setComputePipelineState:") orelse {
        std.debug.print("Failed to get setComputePipelineState selector\n", .{});
        return MetalError.InvalidPipeline;
    };

    if (metal_framework.objc_msgSend_set_state(encoder, set_pipeline_sel, state.compute_pipeline.?) == null) {
        std.debug.print("Failed to set compute pipeline state\n", .{});
        return MetalError.InvalidPipeline;
    }
    std.debug.print("Set compute pipeline state successfully\n", .{});

    // Set buffers
    const set_buffer_sel = metal_framework.sel_registerName("setBuffer:offset:atIndex:") orelse {
        std.debug.print("Failed to get setBuffer selector\n", .{});
        return MetalError.InvalidBuffer;
    };

    // Validate buffers before setting
    if (state.pattern_buffer == null) {
        std.debug.print("Pattern buffer is null\n", .{});
        return MetalError.InvalidBuffer;
    }
    if (state.output_buffer == null) {
        std.debug.print("Output buffer is null\n", .{});
        return MetalError.InvalidBuffer;
    }

    // Set pattern buffer
    if (metal_framework.objc_msgSend_set_buffer(encoder, set_buffer_sel, state.pattern_buffer.?, 0, 0) == null) {
        std.debug.print("Failed to set pattern buffer\n", .{});
        return MetalError.InvalidBuffer;
    }
    std.debug.print("Set pattern buffer successfully\n", .{});

    // Set output buffer
    if (metal_framework.objc_msgSend_set_buffer(encoder, set_buffer_sel, state.output_buffer.?, 0, 1) == null) {
        std.debug.print("Failed to set output buffer\n", .{});
        return MetalError.InvalidBuffer;
    }
    std.debug.print("Set output buffer successfully\n", .{});

    // Dispatch compute
    metal_framework.MetalFramework.dispatch_compute(encoder, grid_size, group_size);

    // Synchronize managed buffers
    const sync_sel = metal_framework.sel_registerName("didModifyRange:") orelse {
        std.debug.print("Failed to get didModifyRange selector\n", .{});
        return MetalError.InvalidBuffer;
    };

    const length_sel = metal_framework.sel_registerName("length") orelse {
        std.debug.print("Failed to get length selector\n", .{});
        return MetalError.InvalidBuffer;
    };

    const buffer_length = metal_framework.objc_msgSend_length(state.output_buffer.?, length_sel);
    const range = metal_framework.MTLRange{
        .location = 0,
        .length = buffer_length,
    };
    _ = metal_framework.objc_msgSend_sync_buffer(state.output_buffer.?, sync_sel, range);

    // End compute encoding
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

    // Get contents pointer and copy data
    const contents_sel = metal_framework.sel_registerName("contents") orelse {
        std.debug.print("Failed to get contents selector\n", .{});
        return MetalError.NoBuffer;
    };

    const output_ptr = metal_framework.objc_msgSend_basic(state.output_buffer.?, contents_sel) orelse {
        std.debug.print("Failed to get output buffer contents\n", .{});
        return MetalError.NoBuffer;
    };

    // Copy directly from Metal buffer to output buffer
    const output_slice = @as([*]u8, @ptrCast(@alignCast(output_ptr)))[0..output_buffer.len];
    @memcpy(output_buffer, output_slice);

    std.debug.print("Metal State: Results retrieved successfully\n", .{});
}
