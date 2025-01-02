const std = @import("std");
const Pattern = @import("pattern.zig").Pattern;

pub const SearchState = struct {
    pattern: Pattern,
    found: bool = false,
    keypair: ?struct {
        public: []u8,
        private: []u8,
    } = null,

    pub fn init(pattern_str: []const u8, case_sensitive: bool) SearchState {
        return SearchState{
            .pattern = Pattern.init(pattern_str, case_sensitive),
        };
    }

    pub fn deinit(self: *SearchState, allocator: std.mem.Allocator) void {
        if (self.keypair) |kp| {
            allocator.free(kp.public);
            allocator.free(kp.private);
        }
    }
};
