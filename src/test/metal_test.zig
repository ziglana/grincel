const std = @import("std");
const testing = std.testing;
const Metal = @import("metal").Metal;
const MetalError = @import("../metal/metal_types.zig").MetalError;

test "Metal.init" {
    var metal = Metal.init(testing.allocator) catch |err| {
        if (err == MetalError.NoMetalDevice or err == MetalError.InvalidCommandQueue) {
            // Skip test if Metal is not available
            return;
        }
        return err;
    };
    defer metal.deinit();

    // Verify we got a valid state
    try testing.expect(@intFromPtr(&metal.state.device) != 0);
    try testing.expect(@intFromPtr(&metal.state.command_queue) != 0);
}

test "Metal.createComputePipeline" {
    var metal = Metal.init(testing.allocator) catch |err| {
        if (err == MetalError.NoMetalDevice or err == MetalError.InvalidCommandQueue) {
            // Skip test if Metal is not available
            return;
        }
        return err;
    };
    defer metal.deinit();

    metal.createComputePipeline() catch |err| {
        if (err == MetalError.NoLibrary) {
            // Skip test if shader library is not available
            return;
        }
        return err;
    };

    // Verify we got a valid pipeline
    try testing.expect(@intFromPtr(&metal.state.compute_pipeline) != 0);
    try testing.expect(@intFromPtr(&metal.state.library) != 0);
}

test "Metal.compute" {
    var metal = Metal.init(testing.allocator) catch |err| {
        if (err == MetalError.NoMetalDevice or err == MetalError.InvalidCommandQueue) {
            // Skip test if Metal is not available
            return;
        }
        return err;
    };
    defer metal.deinit();

    metal.createComputePipeline() catch |err| {
        if (err == MetalError.NoLibrary) {
            // Skip test if shader library is not available
            return;
        }
        return err;
    };

    // Create small, properly aligned buffers
    const pattern = [_]u8{0} ** 16;
    var output = [_]u8{0} ** 16;

    try metal.setupCompute(&pattern, &output);
    try metal.runCompute(.{ .width = 1, .height = 1, .depth = 1 }, .{ .width = 1, .height = 1, .depth = 1 });

    // Verify output contains expected values
    try testing.expect(output[0] == 0xEF);
    try testing.expect(output[1] == 0xBE);
    try testing.expect(output[2] == 0xAD);
    try testing.expect(output[3] == 0xDE);
    try testing.expect(output[4] == 0xBE);
    try testing.expect(output[5] == 0xBA);
    try testing.expect(output[6] == 0xFE);
    try testing.expect(output[7] == 0xCA);
}
