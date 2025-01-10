const std = @import("std");
const Vector = @Vector(32, u8);

pub const Base58 = struct {
    const ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

    // Pre-computed lookup tables for faster encoding
    const ENCODE_MAP = init: {
        @setEvalBranchQuota(10000);
        var map: [256][5]u8 = undefined;
        for (&map) |*entry| {
            @memset(entry, 0);
        }
        for (0..256) |i| {
            var num = i;
            var pos: usize = 0;
            while (num > 0) : (pos += 1) {
                const rem = num % 58;
                num /= 58;
                map[i][pos] = ALPHABET[rem];
            }
            if (pos == 0) {
                map[i][0] = ALPHABET[0];
                pos = 1;
            }
            // Reverse the result
            var j: usize = 0;
            while (j < pos / 2) : (j += 1) {
                const temp = map[i][j];
                map[i][j] = map[i][pos - 1 - j];
                map[i][pos - 1 - j] = temp;
            }
        }
        break :init map;
    };

    // Pre-computed division lookup table
    const DIV_TABLE = init: {
        @setEvalBranchQuota(10000);
        var table: [256]struct { div: u8, rem: u8 } = undefined;
        for (0..256) |i| {
            table[i] = .{
                .div = @truncate(i / 58),
                .rem = @truncate(i % 58),
            };
        }
        break :init table;
    };

    // Fast path for encoding small inputs (1-4 bytes)
    pub fn encodeSmall(out: []u8, input: []const u8) !usize {
        if (input.len == 0) return 0;
        if (input.len > 4) return error.InputTooLong;

        // Use lookup table for first byte
        const first = input[0];
        const first_encoded = ENCODE_MAP[first];
        var len: usize = 0;
        while (len < 5 and first_encoded[len] != 0) : (len += 1) {
            out[len] = first_encoded[len];
        }

        // Handle additional bytes using division lookup table
        if (input.len > 1) {
            var value: u32 = first;
            for (input[1..]) |byte| {
                value = value * 256 + byte;
            }

            var temp: [10]u8 = undefined;
            var pos: usize = 0;
            while (value > 0) : (pos += 1) {
                const entry = DIV_TABLE[value & 0xff];
                value = (value >> 8) + (@as(u32, entry.div) << 24);
                temp[pos] = ALPHABET[entry.rem];
            }

            // Copy reversed result
            while (pos > 0) {
                pos -= 1;
                out[len] = temp[pos];
                len += 1;
            }
        }

        return len;
    }

    pub fn encode(out: []u8, input: []const u8) !usize {
        if (input.len == 0) return 0;

        // Fast path for small inputs
        if (input.len <= 4) {
            return encodeSmall(out, input);
        }

        // Count leading zeros
        var zeros: usize = 0;
        while (zeros < input.len and input[zeros] == 0) : (zeros += 1) {
            out[zeros] = '1';
        }

        // Process remaining bytes in chunks using SIMD
        var b58: [128]u8 = undefined;
        var length: usize = 0;

        // Convert to base58 using lookup tables
        var i: usize = zeros;
        while (i < input.len) : (i += 1) {
            const byte = input[i];
            var carry: u32 = byte;
            var j: usize = 0;

            // Use division lookup table for better performance
            while (j < length or carry != 0) : (j += 1) {
                if (j < length) {
                    carry += @as(u32, b58[j]) * 256;
                }
                const entry = DIV_TABLE[carry & 0xff];
                carry = (carry >> 8) + (@as(u32, entry.div) << 24);
                b58[j] = entry.rem;
            }
            length = j;
        }

        // Skip leading zeros in b58
        var b58_zeros: usize = 0;
        while (b58_zeros < length and b58[length - 1 - b58_zeros] == 0) : (b58_zeros += 1) {}

        // Copy result
        if (zeros + length - b58_zeros > out.len) return error.NoSpace;

        var j: usize = 0;
        while (j < length - b58_zeros) : (j += 1) {
            out[zeros + j] = ALPHABET[b58[length - 1 - b58_zeros - j]];
        }

        return zeros + length - b58_zeros;
    }
};
