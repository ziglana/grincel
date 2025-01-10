const std = @import("std");
const metal_init = @import("metal/metal_init.zig");
const metal_pipeline = @import("metal/metal_pipeline.zig");
const metal_compute = @import("metal/metal_compute.zig");
const metal_types = @import("metal/metal_types.zig");

pub const MetalError = metal_types.MetalError;
pub const MetalState = metal_types.MetalState;

pub fn initMetal() !MetalState {
    return metal_init.initMetal();
}

pub fn deinitMetal(state: *MetalState) void {
    metal_init.deinitMetal(state);
}

pub fn createPipeline(state: *MetalState, function_name: [*:0]const u8) !void {
    try metal_pipeline.createPipeline(state, function_name);
}

pub fn setupCompute(state: *MetalState, pattern_buffer: []const u8, output_buffer: []u8) !void {
    try metal_compute.setupCompute(state, pattern_buffer, output_buffer);
}

pub fn runCompute(state: *MetalState, grid_size: @import("metal_framework.zig").MTLSize, group_size: @import("metal_framework.zig").MTLSize) !void {
    try metal_compute.runCompute(state, grid_size, group_size);
}

pub fn getResults(state: *MetalState, output_buffer: []u8) !void {
    try metal_compute.getResults(state, output_buffer);
}

test "metal" {
    std.testing.refAllDecls(@This());
}
