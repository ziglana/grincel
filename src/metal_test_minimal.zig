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

    const KeyPair = struct {
        private_key: [32]u8 align(4),
        _padding1: [16]u8 align(4),
        public_key: [32]u8 align(4),
        _padding2: [16]u8 align(4),
        debug: [36]u32 align(4),
        _padding3: [48]u8 align(4),
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

    // Create test pattern
    var pattern = Pattern{
        .pattern_length = 4,
        .fixed_chars = [_]u32{0} ** 8,
        .mask = [_]u32{0} ** 8,
        .case_sensitive = 1,
    };

    // Create test key pair buffer
    var key_pair = KeyPair{
        .private_key = [_]u8{0} ** 32,
        ._padding1 = [_]u8{0} ** 16,
        .public_key = [_]u8{0} ** 32,
        ._padding2 = [_]u8{0} ** 16,
        .debug = [_]u32{0} ** 36,
        ._padding3 = [_]u8{0} ** 48,
    };

    // Set up compute resources
    try metal.setupCompute(&state, std.mem.asBytes(&pattern), std.mem.asBytes(&key_pair));

    // Run compute
    const grid_size = metal_framework.MTLSize{ .width = 1, .height = 1, .depth = 1 };
    const group_size = metal_framework.MTLSize{ .width = 1, .height = 1, .depth = 1 };
    try metal.runCompute(&state, grid_size, group_size);

    // Get results
    try metal.getResults(&state, std.mem.asBytes(&key_pair));

    // Print debug values
    std.debug.print("\nDebug values:\n", .{});
    for (key_pair.debug, 0..) |value, i| {
        std.debug.print("debug[{}] = 0x{X:0>8}\n", .{ i, value });
    }
}
