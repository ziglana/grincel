const std = @import("std");

pub const MetalError = error{
    NoMetalDevice,
    NoCommandQueue,
    NoCommandBuffer,
    NoCommandEncoder,
    NoPipelineState,
    NoBuffer,
    NoFunction,
    NoLibrary,
    InvalidBufferSize,
    InvalidCommandQueue,
    InvalidCommandEncoder,
    InvalidPipeline,
    InvalidBuffer,
    InvalidFunction,
    InvalidLibrary,
    InvalidThreadgroupMemory,
    InvalidThreadgroupSize,
    InvalidGridSize,
    InvalidResource,
    InvalidState,
};

pub const MetalState = struct {
    device: ?*anyopaque,
    command_queue: ?*anyopaque,
    compute_pipeline: ?*anyopaque,
    pattern_buffer: ?*anyopaque,
    output_buffer: ?*anyopaque,
    library: ?*anyopaque,

    pub fn init() MetalState {
        return .{
            .device = null,
            .command_queue = null,
            .compute_pipeline = null,
            .pattern_buffer = null,
            .output_buffer = null,
            .library = null,
        };
    }

    pub fn validate(self: *const MetalState) !void {
        if (self.device == null) return MetalError.NoMetalDevice;
        if (self.command_queue == null) return MetalError.InvalidCommandQueue;
        if (self.compute_pipeline == null) return MetalError.InvalidPipeline;
    }

    pub fn validateBuffers(self: *const MetalState) !void {
        if (self.pattern_buffer == null) return MetalError.InvalidBuffer;
        if (self.output_buffer == null) return MetalError.InvalidBuffer;
    }

    pub fn validatePipeline(self: *const MetalState) !void {
        if (self.compute_pipeline == null) return MetalError.InvalidPipeline;
    }

    pub fn deinit(self: *MetalState) void {
        const release_sel = @import("../metal_framework.zig").sel_registerName("release");

        if (self.library) |library| {
            _ = @import("../metal_framework.zig").objc_msgSend_basic(library, release_sel);
            self.library = null;
        }

        if (self.compute_pipeline) |pipeline| {
            _ = @import("../metal_framework.zig").objc_msgSend_basic(pipeline, release_sel);
            self.compute_pipeline = null;
        }

        if (self.command_queue) |queue| {
            _ = @import("../metal_framework.zig").objc_msgSend_basic(queue, release_sel);
            self.command_queue = null;
        }

        if (self.device) |device| {
            _ = @import("../metal_framework.zig").objc_msgSend_basic(device, release_sel);
            self.device = null;
        }

        if (self.pattern_buffer) |buffer| {
            _ = @import("../metal_framework.zig").objc_msgSend_basic(buffer, release_sel);
            self.pattern_buffer = null;
        }

        if (self.output_buffer) |buffer| {
            _ = @import("../metal_framework.zig").objc_msgSend_basic(buffer, release_sel);
            self.output_buffer = null;
        }
    }
};
