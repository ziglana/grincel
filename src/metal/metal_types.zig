const std = @import("std");
const metal_framework = @import("../metal_framework.zig");

pub const MetalError = error{
    NoDevice,
    NoCommandQueue,
    NoLibrary,
    NoFunction,
    NoPipeline,
    NoBuffer,
    InvalidDevice,
    InvalidLibrary,
    InvalidFunction,
    InvalidPipeline,
    InvalidBuffer,
    InvalidCommandQueue,
    InvalidCommandEncoder,
};

pub const MetalState = struct {
    device: ?*anyopaque,
    command_queue: ?*anyopaque,
    library: ?*anyopaque,
    compute_pipeline: ?*anyopaque,
    pattern_buffer: ?*anyopaque,
    output_buffer: ?*anyopaque,

    pub fn init() MetalState {
        return MetalState{
            .device = null,
            .command_queue = null,
            .library = null,
            .compute_pipeline = null,
            .pattern_buffer = null,
            .output_buffer = null,
        };
    }

    pub fn deinit(self: *MetalState) void {
        const release_sel = metal_framework.sel_registerName("release");
        if (release_sel) |sel| {
            // Release buffers first
            if (self.pattern_buffer) |buffer| {
                _ = metal_framework.objc_msgSend_basic(buffer, sel);
                self.pattern_buffer = null;
            }
            if (self.output_buffer) |buffer| {
                _ = metal_framework.objc_msgSend_basic(buffer, sel);
                self.output_buffer = null;
            }

            // Release pipeline
            if (self.compute_pipeline) |pipeline| {
                _ = metal_framework.objc_msgSend_basic(pipeline, sel);
                self.compute_pipeline = null;
            }

            // Release library
            if (self.library) |library| {
                _ = metal_framework.objc_msgSend_basic(library, sel);
                self.library = null;
            }

            // Release command queue
            if (self.command_queue) |queue| {
                _ = metal_framework.objc_msgSend_basic(queue, sel);
                self.command_queue = null;
            }

            // Release device last
            if (self.device) |device| {
                _ = metal_framework.objc_msgSend_basic(device, sel);
                self.device = null;
            }
        }
    }

    pub fn isValid(self: *const MetalState) bool {
        return self.device != null and
            self.command_queue != null and
            self.library != null and
            self.compute_pipeline != null;
    }

    pub fn hasBuffers(self: *const MetalState) bool {
        return self.pattern_buffer != null and
            self.output_buffer != null;
    }

    pub fn validate(self: *const MetalState) !void {
        // Validate device
        if (self.device == null) return MetalError.NoDevice;

        // Validate device capabilities
        const max_threads = metal_framework.MetalFramework.get_max_threads_per_threadgroup(self.device);
        if (max_threads.width == 0 or max_threads.height == 0 or max_threads.depth == 0) {
            std.debug.print("Invalid max threads per threadgroup: ({}, {}, {})\n", .{
                max_threads.width,
                max_threads.height,
                max_threads.depth,
            });
            return MetalError.InvalidDevice;
        }

        const max_memory = metal_framework.MetalFramework.get_max_threadgroup_memory_length(self.device);
        if (max_memory == 0) {
            std.debug.print("Invalid max threadgroup memory length: {}\n", .{max_memory});
            return MetalError.InvalidDevice;
        }

        // Validate command queue
        if (self.command_queue == null) return MetalError.NoCommandQueue;
        const queue_device = metal_framework.MTLFunction_getDevice(self.command_queue);
        if (queue_device == null or queue_device != self.device) {
            std.debug.print("Command queue device mismatch\n", .{});
            return MetalError.InvalidCommandQueue;
        }
    }

    pub fn validateBuffers(self: *const MetalState) !void {
        if (self.pattern_buffer == null) return MetalError.NoBuffer;
        if (self.output_buffer == null) return MetalError.NoBuffer;

        // Validate buffer devices
        const pattern_device = metal_framework.MTLFunction_getDevice(self.pattern_buffer);
        if (pattern_device == null or pattern_device != self.device) {
            std.debug.print("Pattern buffer device mismatch\n", .{});
            return MetalError.InvalidBuffer;
        }

        const output_device = metal_framework.MTLFunction_getDevice(self.output_buffer);
        if (output_device == null or output_device != self.device) {
            std.debug.print("Output buffer device mismatch\n", .{});
            return MetalError.InvalidBuffer;
        }
    }

    pub fn validateDevice(self: *const MetalState, device: ?*anyopaque) !void {
        if (device == null) return MetalError.InvalidDevice;
        if (device != self.device) return MetalError.InvalidDevice;
    }

    pub fn validatePipeline(self: *const MetalState) !void {
        if (self.compute_pipeline == null) return MetalError.NoPipeline;
        const pipeline_device = metal_framework.MTLFunction_getDevice(self.compute_pipeline);
        if (pipeline_device == null or pipeline_device != self.device) {
            std.debug.print("Pipeline device mismatch\n", .{});
            return MetalError.InvalidPipeline;
        }
    }
};
