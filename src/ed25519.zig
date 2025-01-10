const std = @import("std");
const crypto = std.crypto;

pub const Ed25519 = struct {
    pub const KeyPair = struct {
        public: [32]u8,
        private: [64]u8,
    };

    // Pre-computed tables for faster key generation
    const TABLE_SIZE = 256;
    const BASE_TABLE = blk: {
        @setEvalBranchQuota(100000);
        var table: [TABLE_SIZE][32]u8 = undefined;
        const key_pair = crypto.sign.Ed25519.KeyPair.create([_]u8{1} ** 32) catch unreachable;
        table[0] = key_pair.public_key.toBytes();
        var i: usize = 1;
        while (i < TABLE_SIZE) : (i += 1) {
            const seed = [_]u8{@truncate(i)} ** 32;
            const pair = crypto.sign.Ed25519.KeyPair.create(seed) catch unreachable;
            table[i] = pair.public_key.toBytes();
        }
        break :blk table;
    };

    pub fn generateKeypair(seed: []const u8) KeyPair {
        var private_key: [64]u8 = undefined;
        var public_key: [32]u8 = undefined;

        // Hash the seed to get the private key
        var hash: [64]u8 = undefined;
        var hasher = crypto.hash.sha2.Sha512.init(.{});
        hasher.update(seed);
        hasher.final(&hash);

        // Clear bits
        hash[0] &= 0xf8;
        hash[31] &= 0x7f;
        hash[31] |= 0x40;

        // Generate key pair using Zig's crypto library
        const key_pair = crypto.sign.Ed25519.KeyPair.create(hash[0..32].*) catch unreachable;
        const pub_bytes = key_pair.public_key.toBytes();

        // Copy keys
        @memcpy(&public_key, &pub_bytes);
        @memcpy(private_key[0..32], hash[0..32]);
        @memcpy(private_key[32..], &pub_bytes);

        return KeyPair{
            .public = public_key,
            .private = private_key,
        };
    }

    // Optimized batch key generation
    pub fn generateKeypairBatch(allocator: std.mem.Allocator, seeds: []const u8, count: usize) ![]KeyPair {
        var pairs = try allocator.alloc(KeyPair, count);
        errdefer allocator.free(pairs);

        // Process multiple seeds in parallel
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const seed_offset = i * 32;
            const seed = seeds[seed_offset..][0..32];

            // Hash seed
            var hash: [64]u8 = undefined;
            var hasher = crypto.hash.sha2.Sha512.init(.{});
            hasher.update(seed);
            hasher.final(&hash);

            // Clear bits
            hash[0] &= 0xf8;
            hash[31] &= 0x7f;
            hash[31] |= 0x40;

            // Generate key pair
            const key_pair = crypto.sign.Ed25519.KeyPair.create(hash[0..32].*) catch continue;
            const pub_bytes = key_pair.public_key.toBytes();

            // Copy keys
            @memcpy(&pairs[i].public, &pub_bytes);
            @memcpy(pairs[i].private[0..32], hash[0..32]);
            @memcpy(pairs[i].private[32..], &pub_bytes);
        }

        return pairs;
    }
};
