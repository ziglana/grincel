const std = @import("std");
const SearchState = @import("search_state").SearchState;

pub const Vulkan = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Vulkan {
        return Vulkan{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Vulkan) void {
        _ = self;
    }

    pub fn createComputePipeline(self: *Vulkan) !void {
        _ = self;
    }

    pub fn dispatchCompute(self: *Vulkan, state: ?*SearchState, workgroup_size: u32) !void {
        _ = self;
        _ = state;
        _ = workgroup_size;
    }
};
