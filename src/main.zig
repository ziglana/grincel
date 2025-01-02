const std = @import("std");
const Metal = @import("metal.zig").Metal;
const SearchState = @import("search_state.zig").SearchState;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get pattern from environment
    const pattern = std.process.getEnvVarOwned(allocator, "VANITY_PATTERN") catch |err| {
        if (err == error.EnvironmentVariableNotFound) {
            std.debug.print("Error: VANITY_PATTERN environment variable not set\n", .{});
            return;
        }
        return err;
    };
    defer allocator.free(pattern);

    // Initialize search state
    var state = SearchState{
        .pattern = .{
            .raw = pattern,
            .case_sensitive = true,
        },
        .found = false,
        .keypair = null,
    };
    defer if (state.keypair) |kp| {
        allocator.free(kp.public);
        allocator.free(kp.private);
    };

    // Initialize GPU backend
    var metal = try Metal.init(allocator);
    defer metal.deinit();

    // Print search parameters
    std.debug.print("Using GPU backend: metal\n", .{});
    std.debug.print("Pattern: {s} ({d} fixed characters)\n", .{ state.pattern.raw, state.pattern.raw.len });
    std.debug.print("Case-sensitive: {}\n", .{state.pattern.case_sensitive});
    std.debug.print("Searching for Solana addresses matching pattern...\n", .{});

    // Compile Metal shader
    try metal.createComputePipeline();
    try metal.dispatchCompute(&state, 256);

    // Print result if found
    if (state.found) {
        if (state.keypair) |kp| {
            std.debug.print("\nFound matching keypair!\n", .{});
            std.debug.print("Public:  {s}\n", .{kp.public});
            std.debug.print("Private: {s}\n", .{kp.private});
        }
    }
}
