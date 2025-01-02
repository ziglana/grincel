const std = @import("std");

pub const Pattern = struct {
    raw: []const u8,
    case_sensitive: bool,

    pub fn init(pattern: []const u8, case_sensitive: bool) Pattern {
        return Pattern{
            .raw = pattern,
            .case_sensitive = case_sensitive,
        };
    }

    pub fn matches(self: Pattern, input: []const u8) bool {
        if (input.len < self.raw.len) return false;

        // Compare only up to pattern length
        const len = @min(input.len, self.raw.len);
        if (self.case_sensitive) {
            return std.mem.eql(u8, input[0..len], self.raw[0..len]);
        } else {
            for (0..len) |i| {
                const a = std.ascii.toUpper(input[i]);
                const b = std.ascii.toUpper(self.raw[i]);
                if (a != b) return false;
            }
            return true;
        }
    }

    pub fn deinit(self: *Pattern, allocator: std.mem.Allocator) void {
        allocator.free(self.raw);
    }
};
