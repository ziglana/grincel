const std = @import("std");

pub const Pattern = extern struct {
    pattern_length: u32,
    _padding1: [3]u32,
    fixed_chars: [8]u32,
    _padding2: [4]u32,
    mask: [8]u32,
    _padding3: [4]u32,
    case_sensitive: u32,
    _padding4: [3]u32,

    comptime {
        std.debug.assert(@sizeOf(@This()) == 128);
        std.debug.assert(@alignOf(@This()) == 4);
    }

    pub fn init(allocator: std.mem.Allocator, pattern_str: []const u8, case_sensitive: bool) !Pattern {
        _ = allocator; // No allocation needed for fixed-size struct

        var result = std.mem.zeroes(Pattern);
        result.pattern_length = @intCast(pattern_str.len);
        result.case_sensitive = @intFromBool(case_sensitive);

        // Convert pattern string to fixed chars and mask
        var fixed_chars = [_]u32{0} ** 8;
        var mask = [_]u32{0} ** 8;

        for (pattern_str, 0..) |c, i| {
            // Divide by 4 to get which u32 we're in
            const byte_pos: u32 = @intCast(i >> 2);

            // Multiply by 8 to get bit position
            const bit_shift: u5 = @intCast((i & 3) * 8);

            if (c != '?') {
                fixed_chars[byte_pos] |= @as(u32, c) << bit_shift;
                const mask_val: u32 = 0xFF;
                mask[byte_pos] |= mask_val << bit_shift;
            }
        }

        @memcpy(result.fixed_chars[0..], &fixed_chars);
        @memcpy(result.mask[0..], &mask);

        return result;
    }

    pub fn deinit(self: *Pattern) void {
        _ = self; // No memory to free
    }

    pub fn matches(self: Pattern, input: []const u8) bool {
        // Early return if input is shorter than pattern
        if (input.len < self.pattern_length) return false;

        // Try matching at each position in input
        const max_start = input.len - self.pattern_length;
        var start: usize = 0;
        while (start <= max_start) : (start += 1) {
            if (self.matchesAt(input[start..])) return true;
        }
        return false;
    }

    fn matchesAt(self: Pattern, input: []const u8) bool {
        // Check each character position
        var i: usize = 0;
        while (i < self.pattern_length) : (i += 1) {
            const byte_pos = i >> 2; // Divide by 4 to get which u32 we're in
            const bit_shift: u5 = @intCast((i & 3) * 8);
            const mask_byte = (self.mask[byte_pos] >> bit_shift) & 0xFF;

            // Skip wildcard characters
            if (mask_byte == 0) continue;

            const pattern_char = (self.fixed_chars[byte_pos] >> bit_shift) & 0xFF;
            const input_char = input[i];

            if (self.case_sensitive == 1) {
                if (pattern_char != input_char) return false;
            } else {
                const pattern_upper = std.ascii.toUpper(@intCast(pattern_char));
                const input_upper = std.ascii.toUpper(input_char);
                if (pattern_upper != input_upper) return false;
            }
        }
        return true;
    }
};

test "Pattern struct layout" {
    std.debug.print("\nPattern size: {}, alignment: {}\n", .{ @sizeOf(Pattern), @alignOf(Pattern) });
    std.debug.print("pattern_length offset: {}\n", .{@offsetOf(Pattern, "pattern_length")});
    std.debug.print("fixed_chars offset: {}\n", .{@offsetOf(Pattern, "fixed_chars")});
    std.debug.print("mask offset: {}\n", .{@offsetOf(Pattern, "mask")});
    std.debug.print("case_sensitive offset: {}\n", .{@offsetOf(Pattern, "case_sensitive")});

    try std.testing.expectEqual(@sizeOf(Pattern), 128);
    try std.testing.expectEqual(@alignOf(Pattern), 4);
    try std.testing.expectEqual(@offsetOf(Pattern, "pattern_length"), 0);
    try std.testing.expectEqual(@offsetOf(Pattern, "fixed_chars"), 16);
    try std.testing.expectEqual(@offsetOf(Pattern, "mask"), 64);
    try std.testing.expectEqual(@offsetOf(Pattern, "case_sensitive"), 112);
}
