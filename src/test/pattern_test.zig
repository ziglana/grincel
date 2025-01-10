const std = @import("std");
const testing = std.testing;
const Pattern = @import("pattern").Pattern;

test "pattern matching - exact match" {
    const allocator = testing.allocator;
    var pattern = try Pattern.init(allocator, "cafe", true);
    defer pattern.deinit();

    try testing.expect(pattern.matches("cafe1234")); // Pattern at start
    try testing.expect(pattern.matches("1cafe234")); // Pattern in middle
    try testing.expect(pattern.matches("1234cafe")); // Pattern at end
    try testing.expect(!pattern.matches("caf1234")); // Incomplete pattern
}

test "pattern matching - case insensitive" {
    const allocator = testing.allocator;
    var pattern = try Pattern.init(allocator, "CAFE", false);
    defer pattern.deinit();

    try testing.expect(pattern.matches("cafe1234")); // Lowercase
    try testing.expect(pattern.matches("CAFE1234")); // Uppercase
    try testing.expect(pattern.matches("CaFe1234")); // Mixed case
    try testing.expect(!pattern.matches("caf1234")); // Incomplete pattern
}

test "pattern matching - wildcards" {
    const allocator = testing.allocator;
    var pattern = try Pattern.init(allocator, "ca?e", true);
    defer pattern.deinit();

    try testing.expect(pattern.matches("cafe1234")); // 'f' matches ?
    try testing.expect(pattern.matches("cake1234")); // 'k' matches ?
    try testing.expect(pattern.matches("cave1234")); // 'v' matches ?
    try testing.expect(!pattern.matches("ca1234")); // Missing character for ?
}

test "pattern matching - mixed case and wildcards" {
    const allocator = testing.allocator;
    var pattern = try Pattern.init(allocator, "Ca?E", false);
    defer pattern.deinit();

    try testing.expect(pattern.matches("cafe1234")); // Lowercase with 'f' matching ?
    try testing.expect(pattern.matches("CAKE1234")); // Uppercase with 'K' matching ?
    try testing.expect(pattern.matches("CaVe1234")); // Mixed case with 'V' matching ?
    try testing.expect(!pattern.matches("cae1234")); // Missing character for ?
}
