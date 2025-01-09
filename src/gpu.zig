const std = @import("std");
const builtin = @import("builtin");
const SearchState = @import("search_state").SearchState;
const Metal = @import("metal").Metal;
const Vulkan = @import("vulkan").Vulkan;

pub const GpuBackend = enum {
    vulkan,
    metal,
};

pub const GpuManager = struct {
    backend: GpuBackend,
    impl: union {
        vulkan: Vulkan,
        metal: Metal,
    },

    pub fn init(allocator: std.mem.Allocator) !GpuManager {
        if (builtin.os.tag == .macos) {
            return GpuManager{
                .backend = .metal,
                .impl = .{ .metal = try Metal.init(allocator) },
            };
        } else {
            return GpuManager{
                .backend = .vulkan,
                .impl = .{ .vulkan = try Vulkan.init(allocator) },
            };
        }
    }

    pub fn deinit(self: *GpuManager) void {
        switch (self.backend) {
            .vulkan => self.impl.vulkan.deinit(),
            .metal => self.impl.metal.deinit(),
        }
    }

    pub fn createComputePipeline(self: *GpuManager) !void {
        switch (self.backend) {
            .vulkan => return self.impl.vulkan.createComputePipeline(),
            .metal => return self.impl.metal.createComputePipeline(),
        }
    }

    pub fn dispatchCompute(self: *GpuManager, state: ?*SearchState, workgroup_size: u32) !void {
        switch (self.backend) {
            .vulkan => return self.impl.vulkan.dispatchCompute(state, workgroup_size),
            .metal => return self.impl.metal.dispatchCompute(state, workgroup_size),
        }
    }
};
