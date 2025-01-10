const std = @import("std");
const Pattern = @import("pattern").Pattern;

pub fn pattern_to_mask(pattern: []const u8) u32 {
    var mask: u32 = 0;
    for (pattern, 0..) |c, i| {
        if (c != '*') {
            mask |= @as(u32, 1) << @as(u5, @truncate(i));
        }
    }
    return mask;
}
