const std = @import("std");
const SearchState = @import("search_state.zig").SearchState;
const Ed25519 = @import("ed25519.zig").Ed25519;
const Base58 = @import("base58.zig").Base58;
const MetalFramework = @import("metal_framework.zig").MetalFramework;

const MetalError = error{
    NoDevice,
    NoCommandQueue,
    NoLibrary,
    NoKernel,
    NoPipeline,
    NoBuffer,
    NoCommandBuffer,
    NoEncoder,
};

pub const Metal = struct {
    allocator: std.mem.Allocator,
    attempts: std.atomic.Value(u64),
    start_time: i64,
    last_report_time: i64,
    should_stop: std.atomic.Value(bool),

    // Metal state
    metal: MetalFramework,
    device: MetalFramework.Device,
    command_queue: MetalFramework.CommandQueue,
    compute_pipeline: MetalFramework.ComputePipelineState,

    // Performance counters
    compute_time: std.atomic.Value(u64),
    transfer_time: std.atomic.Value(u64),

    const Self = @This();
    const WORKGROUP_SIZE = 256; // Optimal for most Metal GPUs
    const MAX_BUFFER_SIZE = 1024 * 1024; // 1MB buffer size

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Initialize Metal framework
        var metal = try MetalFramework.init();

        // Get default Metal device
        const device = metal.create_system_default_device() orelse {
            return MetalError.NoDevice;
        };

        // Create command queue
        const command_queue = metal.new_command_queue(device) orelse {
            return MetalError.NoCommandQueue;
        };

        const now = std.time.milliTimestamp();
        return Self{
            .allocator = allocator,
            .attempts = std.atomic.Value(u64).init(0),
            .start_time = now,
            .last_report_time = now,
            .should_stop = std.atomic.Value(bool).init(false),
            .metal = metal,
            .device = device,
            .command_queue = command_queue,
            .compute_pipeline = undefined, // Set in createComputePipeline
            .compute_time = std.atomic.Value(u64).init(0),
            .transfer_time = std.atomic.Value(u64).init(0),
        };
    }

    pub fn deinit(self: *Self) void {
        // Metal framework handles cleanup of device and command queue
        _ = self;
    }

    pub fn createComputePipeline(self: *Self) !void {
        // Load precompiled Metal library
        const err: ?**anyopaque = null;
        const library = self.metal.new_library_with_file(self.device, "zig-out/lib/vanity.metallib", err) orelse {
            std.debug.print("Failed to load Metal library\n", .{});
            if (err) |error_obj| {
                const desc_sel = MetalFramework.sel_registerName("localizedDescription");
                if (MetalFramework.objc_msgSend(error_obj.*, desc_sel)) |desc_obj| {
                    const desc_str = @as([*:0]const u8, @ptrCast(desc_obj));
                    std.debug.print("Error: {s}\n", .{desc_str});
                }
            }
            return MetalError.NoLibrary;
        };

        // Get compute kernel function
        const kernel_function = self.metal.new_function_with_name(library, "vanityCompute") orelse {
            return MetalError.NoKernel;
        };

        // Create compute pipeline
        self.compute_pipeline = self.metal.new_compute_pipeline_state(self.device, kernel_function, err) orelse {
            return MetalError.NoPipeline;
        };
    }

    fn reportProgress(self: *Self) void {
        const now = std.time.milliTimestamp();
        if (now - self.last_report_time >= 1000) { // Report every second
            self.last_report_time = now;

            const total = self.attempts.load(.monotonic);
            const elapsed_secs = @as(f64, @floatFromInt(now - self.start_time)) / 1000.0;
            const rate = if (elapsed_secs > 0)
                @as(f64, @floatFromInt(total)) / elapsed_secs
            else
                0;

            // Get timing stats
            const compute_time = @as(f64, @floatFromInt(self.compute_time.load(.monotonic))) / 1000.0;
            const transfer_time = @as(f64, @floatFromInt(self.transfer_time.load(.monotonic))) / 1000.0;

            std.debug.print("\rSearched {d} addresses in {d:.1}s. Rate: {d:.0} addr/s | Times: compute={d:.1}s transfer={d:.1}s", .{ total, elapsed_secs, rate, compute_time, transfer_time });
        }
    }

    pub fn dispatchCompute(self: *Self, state: ?*SearchState, workgroup_size: u32) !void {
        if (state == null) return;

        // Reset counters
        self.attempts.store(0, .monotonic);
        self.should_stop.store(false, .monotonic);
        self.start_time = std.time.milliTimestamp();
        self.last_report_time = self.start_time;
        self.compute_time.store(0, .monotonic);
        self.transfer_time.store(0, .monotonic);

        const actual_workgroup_size = @min(workgroup_size, WORKGROUP_SIZE);
        const buffer_size = MAX_BUFFER_SIZE;

        // Create and initialize GPU buffers
        const keys_buffer = blk: {
            const buffer = self.metal.new_buffer_with_length(self.device, buffer_size, .{ .storage_mode = 0 } // Managed
            ) orelse {
                return MetalError.NoBuffer;
            };
            const ptr = self.metal.get_contents(buffer);
            @memset(ptr[0..buffer_size], 0);
            break :blk buffer;
        };

        const pattern_buffer = blk: {
            const pattern_len = state.?.pattern.raw.len;
            const buffer = self.metal.new_buffer_with_length(self.device, 64, // Fixed size for alignment
                .{ .storage_mode = 0 } // Managed
            ) orelse {
                return MetalError.NoBuffer;
            };
            const ptr = self.metal.get_contents(buffer);
            @memset(ptr[0..64], 0);
            @memcpy(ptr[0..pattern_len], state.?.pattern.raw);
            break :blk buffer;
        };

        const pattern_len_buffer = blk: {
            const buffer = self.metal.new_buffer_with_length(self.device, @sizeOf(u32), .{ .storage_mode = 0 } // Managed
            ) orelse {
                return MetalError.NoBuffer;
            };
            const ptr = @as([*]u32, @ptrCast(@alignCast(self.metal.get_contents(buffer))));
            ptr[0] = @intCast(state.?.pattern.raw.len);
            break :blk buffer;
        };

        const found_buffer = blk: {
            const buffer = self.metal.new_buffer_with_length(self.device, @sizeOf(u32), .{ .storage_mode = 0 } // Managed
            ) orelse {
                return MetalError.NoBuffer;
            };
            const ptr = @as([*]u32, @ptrCast(@alignCast(self.metal.get_contents(buffer))));
            ptr[0] = 0; // Initialize to not found
            break :blk buffer;
        };

        while (!self.should_stop.load(.monotonic)) {
            const compute_start = std.time.milliTimestamp();

            // Get command buffer and encoder
            const command_buffer = self.metal.command_buffer(self.command_queue) orelse {
                return MetalError.NoCommandBuffer;
            };

            const compute_encoder = self.metal.compute_command_encoder(command_buffer) orelse {
                return MetalError.NoEncoder;
            };

            // Set compute pipeline and buffers
            self.metal.set_compute_pipeline_state(compute_encoder, self.compute_pipeline);
            self.metal.set_buffer(compute_encoder, keys_buffer, 0, 0);
            self.metal.set_buffer(compute_encoder, pattern_buffer, 0, 1);
            self.metal.set_buffer(compute_encoder, pattern_len_buffer, 0, 2);
            self.metal.set_buffer(compute_encoder, found_buffer, 0, 3);

            // Dispatch compute work
            const grid_size = MetalFramework.Size{
                .width = buffer_size / 64, // 32 bytes each for public and private key
                .height = 1,
                .depth = 1,
            };
            const group_size = MetalFramework.Size{ .width = actual_workgroup_size, .height = 1, .depth = 1 };
            self.metal.dispatch_threadgroups(compute_encoder, grid_size, group_size);
            self.metal.end_encoding(compute_encoder);

            // Execute and wait
            self.metal.commit(command_buffer);
            self.metal.wait_until_completed(command_buffer);

            _ = self.compute_time.fetchAdd(@intCast(std.time.milliTimestamp() - compute_start), .monotonic);

            // Check results
            const transfer_start = std.time.milliTimestamp();
            const keys_ptr = self.metal.get_contents(keys_buffer);
            const keys_len = self.metal.get_length(keys_buffer);

            var i: usize = 0;
            while (i < keys_len) : (i += 64) {
                const private_key = keys_ptr[i..][0..32];
                const public_key = keys_ptr[i + 32 ..][0..32];

                // Only process if keys were written (non-zero)
                if (std.mem.allEqual(u8, public_key, 0)) continue;

                var public_b58: [64]u8 = undefined;
                const pub_len = Base58.encode(&public_b58, public_key) catch continue;
                const pub_str = public_b58[0..pub_len];

                if (state.?.pattern.matches(pub_str)) {
                    var private_b58: [128]u8 = undefined;
                    const priv_len = Base58.encode(&private_b58, private_key) catch continue;
                    const priv_str = private_b58[0..priv_len];

                    // Store result
                    const pub_key = try self.allocator.dupe(u8, pub_str);
                    errdefer self.allocator.free(pub_key);

                    const priv_key = try self.allocator.dupe(u8, priv_str);
                    errdefer self.allocator.free(priv_key);

                    state.?.keypair = .{ .public = pub_key, .private = priv_key };
                    state.?.found = true;
                    self.should_stop.store(true, .monotonic);
                    break;
                }
            }

            _ = self.transfer_time.fetchAdd(@intCast(std.time.milliTimestamp() - transfer_start), .monotonic);
            _ = self.attempts.fetchAdd(buffer_size / 64, .monotonic);

            self.reportProgress();
        }

        // Clear progress line
        std.debug.print("\n", .{});
    }
};
