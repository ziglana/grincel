const std = @import("std");
const metal = @import("metal.zig");
const metal_framework = @import("metal_framework.zig");
const Pattern = @import("pattern.zig").Pattern;

pub fn main() !void {
    std.debug.print("\nZig Pattern struct layout:\n", .{});
    std.debug.print("Total size: {} bytes\n", .{@sizeOf(Pattern)});
    std.debug.print("Alignment: {} bytes\n", .{@alignOf(Pattern)});
    inline for (std.meta.fields(Pattern)) |field| {
        std.debug.print("{s}: offset={} size={} alignment={}\n", .{
            field.name,
            @offsetOf(Pattern, field.name),
            @sizeOf(field.type),
            @alignOf(field.type),
        });
    }
    std.debug.print("\n\n", .{});

    const KeyPair = extern struct {
        private_key: [8]u32, // 32 bytes as u32 array
        _padding1: [4]u32, // 16 bytes as u32 array
        public_key: [8]u32, // 32 bytes as u32 array
        _padding2: [4]u32, // 16 bytes as u32 array
        debug: [36]u32, // Already u32 array
        _padding3: [12]u32, // 48 bytes as u32 array
    };

    std.debug.print("KeyPair struct layout:\n", .{});
    std.debug.print("Total size: {} bytes\n", .{@sizeOf(KeyPair)});
    std.debug.print("Alignment: {} bytes\n", .{@alignOf(KeyPair)});
    inline for (std.meta.fields(KeyPair)) |field| {
        std.debug.print("{s}: offset={} size={} alignment={}\n", .{
            field.name,
            @offsetOf(KeyPair, field.name),
            @sizeOf(field.type),
            @alignOf(field.type),
        });
    }
    std.debug.print("\n", .{});

    std.debug.print("Initializing Metal...\n", .{});
    var state = try metal.initMetal();
    defer metal.deinitMetal(&state);

    std.debug.print("Creating compute pipeline...\n", .{});
    try metal.createPipeline(&state, "compute");

    // Create larger input and output buffers aligned to 16 bytes
    var input: [1024]u32 align(16) = .{
        0x12345678, 0, 0, 0,
        0,          0, 0, 0,
        0,          0, 0, 0,
        0,          0, 0, 0,
    } ** 64;
    var output: [2048]u32 align(16) = .{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    } ** 64;

    std.debug.print("\nInput buffer contents:\n", .{});
    for (input, 0..) |value, i| {
        std.debug.print("input[{}] = 0x{X:0>8}\n", .{ i, value });
    }

    // Set up compute resources with debug prints
    std.debug.print("\nSetting up compute resources...\n", .{});
    try metal.setupCompute(&state, std.mem.asBytes(&input), std.mem.asBytes(&output));
    std.debug.print("Compute resources set up successfully\n", .{});

    // Get max threads per threadgroup
    const max_threads = metal_framework.MetalFramework.get_max_threads_per_threadgroup(state.device);
    std.debug.print("Max threads per threadgroup: ({}, {}, {})\n", .{
        max_threads.width,
        max_threads.height,
        max_threads.depth,
    });

    // Run compute with appropriate thread group size
    std.debug.print("\nRunning compute...\n", .{});
    const grid_size = metal_framework.MTLSize{ .width = 64, .height = 1, .depth = 1 };
    const group_size = metal_framework.MTLSize{
        .width = 64, // Process 64 items in parallel
        .height = 1,
        .depth = 1,
    };
    try metal.runCompute(&state, grid_size, group_size);
    std.debug.print("Compute completed successfully\n", .{});

    // Get results
    try metal.getResults(&state, std.mem.asBytes(&output));

    // Print output values
    std.debug.print("\nOutput values:\n", .{});
    for (output, 0..) |value, i| {
        std.debug.print("output[{}] = 0x{X:0>8}\n", .{ i, value });
    }
}
