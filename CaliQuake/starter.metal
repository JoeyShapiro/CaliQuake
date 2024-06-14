//
//  starter.metal
//  CaliQuake
//
//  Created by Joey Shapiro on 6/12/24.
//

#include <metal_stdlib>
using namespace metal;

//// Structure to hold the input attributes from the vertex shader
//struct VertexOut {
//    float4 position [[position]];
//    float4 color;
//};
//
//// Fragment shader function
//fragment float4 fragment_main(VertexOut in [[stage_in]]) {
//    // Output the color passed from the vertex shader
//    return in.color;
//}
//
//// Structure to hold the input attributes for the vertex shader
//struct VertexIn {
//    float4 position [[attribute(0)]];
//    float4 color [[attribute(1)]];
//};
//
//// Vertex shader function
//vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
//    VertexOut out;
//    out.position = in.position;
//    out.color = in.color;
//    return out;
//}
//
//vertex float4 init(const device float2 * vertices[[buffer(0)]], const uint vid[[vertex_id]]) {
//
//    return float4(vertices[vid], 0, 1);
//}
//
//fragment float4 draw(const device long * tilemap[[buffer(0)]], const float4 coordinates [[position]]) {
//
//    int x = int(coordinates.x) / 80;
//    int y = int(coordinates.y) / 80;
//    int tile = tilemap[y * 16 + x];
//
//    return float4(float(tile), 0, 0, 1);
//}

struct VertexOut {
    float4 position [[ position ]];
    float2 texCoord;
};

vertex VertexOut vertexShader(const device packed_float2 *position [[ buffer(0) ]],
                              const device packed_float2 *texCoord [[ buffer(1) ]],
                              uint vid [[ vertex_id ]]) {
    VertexOut out;
    out.position = float4(position[vid], 0.0, 1.0);
    out.texCoord = texCoord[vid];
    return out;
}

fragment half4 fragmentShader(VertexOut in [[ stage_in ]],
                              texture2d<half> tex [[ texture(0) ]]) {
    constexpr sampler texSampler(mag_filter::linear, min_filter::linear);
    half4 color = tex.sample(texSampler, in.texCoord);
    return color;
}
