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

//fragment half4 fragmentShader(VertexOut in [[ stage_in ]],
//                              texture2d<half> tex [[ texture(0) ]],
//                              texture2d<half> cursor [[ texture(1) ]],
//                              constant float2& resolution [[buffer(0)]],
//                              constant float &mtime [[ buffer(1) ]]) {
//    constexpr sampler texSampler(mag_filter::linear, min_filter::linear);
//    return tex.sample(texSampler, in.texCoord);
//}

/*
 Options:
 - Using Metal's built-in multisampling render targets
 - Implementing a post-processing anti-aliasing technique like FXAA
 - Using temporal anti-aliasing (TAA) for scenarios with motion
 */
fragment half4 fragmentShader(VertexOut in [[ stage_in ]],
                              texture2d<half> tex [[ texture(0) ]],
                              texture2d<half> cursor [[ texture(1) ]],
                              constant float2& resolution [[buffer(0)]],
                              constant float &mtime [[ buffer(1) ]]) {
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
    
    float speed = mtime / 500;
    
    half4 cursorBase = cursor.sample(texSampler, in.texCoord);
    
    // Cursor blur effect
    // TODO use gpu downsampling blur
    float xPixel = (1 / resolution.x) * 3;
    float yPixel = (1 / resolution.y) * 2;
    
    half3 blur = 0;
    blur += cursor.sample(texSampler, float2(in.texCoord.x - 4.0*xPixel, in.texCoord.y - 4.0*yPixel)).rgb * 0.0162162162;
    blur += cursor.sample(texSampler, float2(in.texCoord.x - 3.0*xPixel, in.texCoord.y - 3.0*yPixel)).rgb * 0.0540540541;
    blur += cursor.sample(texSampler, float2(in.texCoord.x - 2.0*xPixel, in.texCoord.y - 2.0*yPixel)).rgb * 0.1216216216;
    blur += cursor.sample(texSampler, float2(in.texCoord.x - 1.0*xPixel, in.texCoord.y - 1.0*yPixel)).rgb * 0.1945945946;
    
    blur += cursor.sample(texSampler, in.texCoord).rgb * 0.2270270270;
    
    blur += cursor.sample(texSampler, float2(in.texCoord.x + 1.0*xPixel, in.texCoord.y + 1.0*yPixel)).rgb * 0.1945945946;
    blur += cursor.sample(texSampler, float2(in.texCoord.x + 2.0*xPixel, in.texCoord.y + 2.0*yPixel)).rgb * 0.1216216216;
    blur += cursor.sample(texSampler, float2(in.texCoord.x + 3.0*xPixel, in.texCoord.y + 3.0*yPixel)).rgb * 0.0540540541;
    blur += cursor.sample(texSampler, float2(in.texCoord.x + 4.0*xPixel, in.texCoord.y + 4.0*yPixel)).rgb * 0.0162162162;
    
    half thresh = 0.1;
    // worst: 0.1*1 + 0.0*1 + 0.0*1 = 0.1
    // blur.r > 0.1 || blur.g > 0.1 || blur.b > 0.1 ? 1.0 : 0.0
    half alpha = dot(blur, 1.0) > thresh;
//    half4 bloomedCursor = cursorBase + half4(blur, alpha);
    
    // Apply the time-based effect
    // simple yet clever :)
    // have to use sin
    half4 finalCursorColor = cursorBase;
    half brightness = sin(speed);
    finalCursorColor.a = max(finalCursorColor.a * brightness, 0.0h);
    
    return mix(half4(col, 1.0h), finalCursorColor, finalCursorColor.a);
}
