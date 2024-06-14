//
//  starter.metal
//  CaliQuake
//
//  Created by Joey Shapiro on 6/12/24.
//

#include <metal_stdlib>
using namespace metal;

// Structure to hold the input attributes from the vertex shader
struct VertexOut {
    float4 position [[position]];
    float4 color;
};

// Fragment shader function
fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    // Output the color passed from the vertex shader
    return in.color;
}

// Structure to hold the input attributes for the vertex shader
struct VertexIn {
    float4 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

// Vertex shader function
vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.color = in.color;
    return out;
}
