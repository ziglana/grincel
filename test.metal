#include <metal_stdlib>
using namespace metal;
kernel void vanityCompute(device uint8_t* keys [[buffer(0)]],
                         uint gid [[thread_position_in_grid]]) {
    keys[gid] = 42;
}
