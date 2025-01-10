#include <metal_stdlib>
using namespace metal;

struct Pattern {
    uint32_t pattern_length;
    uint8_t _padding1[12];  // Pad to 16 bytes
    uint32_t fixed_chars[8];
    uint8_t _padding2[16];  // Pad to next 16-byte boundary
    uint32_t mask[8];
    uint8_t _padding3[16];  // Pad to next 16-byte boundary
    uint32_t case_sensitive;
    uint8_t _padding4[12];  // Pad to final 16-byte boundary
} __attribute__((aligned(16)));

struct KeyPair {
    uint32_t private_key[8] __attribute__((aligned(16)));
    uint32_t _padding1[4];
    uint32_t public_key[8] __attribute__((aligned(16)));
    uint32_t _padding2[4];
    uint32_t debug[36] __attribute__((aligned(16)));
    uint32_t _padding3[12];
} __attribute__((aligned(16)));

kernel void compute(device const Pattern* pattern [[buffer(0)]],
                   device KeyPair* key_pairs [[buffer(1)]],
                   uint thread_position_in_grid [[thread_position_in_grid]]) {
    
    device KeyPair& key_pair = key_pairs[thread_position_in_grid];
    
    // Write test values directly to debug array
    key_pair.debug[0] = 0xDEADBEEF;
    key_pair.debug[1] = 0xCAFEBABE;
    key_pair.debug[2] = 0x12345678;
    
    // Write pattern data
    key_pair.debug[3] = pattern->pattern_length;
    key_pair.debug[4] = pattern->case_sensitive;
    
    // Copy pattern data
    for (uint i = 0; i < 8; i++) {
        key_pair.debug[5 + i] = pattern->fixed_chars[i];
        key_pair.debug[13 + i] = pattern->mask[i];
    }
    
    // Write struct sizes and offsets for debugging
    key_pair.debug[21] = sizeof(Pattern);
    key_pair.debug[22] = 0;   // pattern_length offset (0 bytes)
    key_pair.debug[23] = 16;  // fixed_chars offset (16 bytes)
    key_pair.debug[24] = 64;  // mask offset (64 bytes)
    key_pair.debug[25] = 112; // case_sensitive offset (112 bytes)
    
    // Write buffer addresses for debugging
    key_pair.debug[26] = uint32_t(uintptr_t(pattern) & 0xFFFFFFFF);
    key_pair.debug[27] = uint32_t(uintptr_t(pattern) >> 32);
    key_pair.debug[28] = uint32_t(uintptr_t(&key_pairs[thread_position_in_grid]) & 0xFFFFFFFF);
    key_pair.debug[29] = uint32_t(uintptr_t(&key_pairs[thread_position_in_grid]) >> 32);
    key_pair.debug[30] = uint32_t(uintptr_t(&pattern->pattern_length) & 0xFFFFFFFF);
    key_pair.debug[31] = uint32_t(uintptr_t(&pattern->pattern_length) >> 32);
    key_pair.debug[32] = uint32_t(uintptr_t(&key_pair.debug[0]) & 0xFFFFFFFF);
    key_pair.debug[33] = uint32_t(uintptr_t(&key_pair.debug[0]) >> 32);
    
    // Write thread info
    key_pair.debug[34] = thread_position_in_grid;
    key_pair.debug[35] = 0xFFFFFFFF; // End marker
}
