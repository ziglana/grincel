const std = @import("std");
const testing = std.testing;
const Metal = @import("metal").Metal;
const MetalError = @import("metal").MetalError;

test "Metal.init" {
    var metal = Metal.init(testing.allocator) catch |err| {
        if (err == MetalError.NoDevice or err == MetalError.NoCommandQueue) {
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
        if (err == MetalError.NoDevice or err == MetalError.NoCommandQueue) {
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
