#include <metal_stdlib>
using namespace metal;

kernel void compute(device const uint32_t* input [[buffer(0)]],
                   device uint32_t* output [[buffer(1)]],
                   uint thread_position_in_grid [[thread_position_in_grid]]) {
    
    // Only process if we're the first thread
    if (thread_position_in_grid == 0) {
        // Write multiple values to ensure proper memory access
        output[0] = 0xDEADBEEF;
        output[1] = 0xCAFEBABE;
        output[2] = 0x12345678;
        output[3] = 0x87654321;
    }
}
