const std = @import("std");

pub const Pattern = extern struct {
    pattern_length: u32 align(16),
    _padding1: [12]u8, // Pad to 16 bytes
    fixed_chars: [8]u32 align(16), // 32 bytes
    _padding2: [16]u8, // Pad to next 16-byte boundary
    mask: [8]u32 align(16), // 32 bytes
    _padding3: [16]u8, // Pad to next 16-byte boundary
    case_sensitive: u32 align(16),
    _padding4: [12]u8, // Pad to final 16-byte boundary

    comptime {
        std.debug.assert(@sizeOf(@This()) == 128);
        std.debug.assert(@alignOf(@This()) == 16);
    }

    pub fn init(allocator: std.mem.Allocator, pattern_str: []const u8, case_sensitive: bool) !Pattern {
        _ = allocator;

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
};

test "Pattern struct layout" {
    std.debug.print("\nPattern size: {}, alignment: {}\n", .{ @sizeOf(Pattern), @alignOf(Pattern) });
    std.debug.print("pattern_length offset: {}\n", .{@offsetOf(Pattern, "pattern_length")});
    std.debug.print("fixed_chars offset: {}\n", .{@offsetOf(Pattern, "fixed_chars")});
    std.debug.print("mask offset: {}\n", .{@offsetOf(Pattern, "mask")});
    std.debug.print("case_sensitive offset: {}\n", .{@offsetOf(Pattern, "case_sensitive")});

    try std.testing.expectEqual(@sizeOf(Pattern), 128);
    try std.testing.expectEqual(@alignOf(Pattern), 16);
    try std.testing.expectEqual(@offsetOf(Pattern, "pattern_length"), 0);
    try std.testing.expectEqual(@offsetOf(Pattern, "fixed_chars"), 16);
    try std.testing.expectEqual(@offsetOf(Pattern, "mask"), 64);
    try std.testing.expectEqual(@offsetOf(Pattern, "case_sensitive"), 112);
}
