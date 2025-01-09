const std = @import("std");
const testing = std.testing;
const Pattern = @import("pattern").Pattern;

test "pattern matching - exact match" {
    const allocator = testing.allocator;
    var pattern = try Pattern.init(allocator, "cafe", true);
    defer pattern.deinit();

    try testing.expect(pattern.matches("cafe1234"));
    try testing.expect(!pattern.matches("1cafe234"));
}

test "pattern matching - case insensitive" {
    const allocator = testing.allocator;
    var pattern = try Pattern.init(allocator, "CAFE", false);
    defer pattern.deinit();

    try testing.expect(pattern.matches("cafe1234"));
    try testing.expect(pattern.matches("CAFE1234"));
    try testing.expect(pattern.matches("CaFe1234"));
}

test "pattern matching - wildcards" {
    const allocator = testing.allocator;
    var pattern = try Pattern.init(allocator, "ca?e", true);
    defer pattern.deinit();

    try testing.expect(pattern.matches("cafe1234"));
    try testing.expect(pattern.matches("cake1234"));
    try testing.expect(!pattern.matches("cave1234"));
}

test "pattern matching - mixed case and wildcards" {
    const allocator = testing.allocator;
    var pattern = try Pattern.init(allocator, "Ca?E", false);
    defer pattern.deinit();

    try testing.expect(pattern.matches("cafe1234"));
    try testing.expect(pattern.matches("CAKE1234"));
    try testing.expect(pattern.matches("CaKe1234"));
}
