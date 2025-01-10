const std = @import("std");
const testing = std.testing;
const Ed25519 = @import("ed25519").Ed25519;

test "keypair generation - deterministic" {
    const seed = "test_seed_12345";
    const keypair1 = Ed25519.generateKeypair(seed);
    const keypair2 = Ed25519.generateKeypair(seed);

    try testing.expectEqualSlices(u8, &keypair1.public, &keypair2.public);
    try testing.expectEqualSlices(u8, &keypair1.private, &keypair2.private);
}

test "keypair generation - different seeds" {
    const seed1 = "test_seed_1";
    const seed2 = "test_seed_2";
    const keypair1 = Ed25519.generateKeypair(seed1);
    const keypair2 = Ed25519.generateKeypair(seed2);

    try testing.expect(!std.mem.eql(u8, &keypair1.public, &keypair2.public));
    try testing.expect(!std.mem.eql(u8, &keypair1.private, &keypair2.private));
}
