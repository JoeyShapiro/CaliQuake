//
//  starter.metal
//  CaliQuake
//
//  Created by Joey Shapiro on 6/12/24.
//

#include <metal_stdlib>
using namespace metal;

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

half3 sampleTexture(texture2d<half> tex, float2 uv, sampler texSampler) {
    return half3(tex.sample(texSampler, uv).rgb);
}

/*
 Options:
 - Using Metal's built-in multisampling render targets
 - Implementing a post-processing anti-aliasing technique like FXAA
 - Using temporal anti-aliasing (TAA) for scenarios with motion
 */
fragment half4 fragmentShader(VertexOut in [[ stage_in ]],
                              texture2d<half> tex [[ texture(0) ]],
                              constant float2& resolution [[buffer(0)]]) {
    constexpr sampler texSampler(mag_filter::linear, min_filter::linear);
//    half4 color = tex.sample(texSampler, in.texCoord);
    
    float2 uv = in.texCoord;
    half3 col = half3(0.0h);
    
    // Anti-aliasing: super-sampling
    const float samples = 16.0; // Increase for better quality, decrease for better performance
    const float step = 1.0 / samples;
    
    for (float x = 0.0; x < 1.0; x += step) {
        for (float y = 0.0; y < 1.0; y += step) {
            float2 offset = float2(x, y) / resolution;
            col += sampleTexture(tex, uv + offset, texSampler);
        }
    }
    
    col /= (samples * samples);
    
    return half4(col, 1.0h);
}
