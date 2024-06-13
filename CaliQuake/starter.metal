//
//  starter.metal
//  CaliQuake
//
//  Created by Joey Shapiro on 6/12/24.
//

#include <metal_stdlib>
using namespace metal;

vertex float4 init(const device float2 * vertices[[buffer(0)]], const uint vid[[vertex_id]]) {

    return float4(vertices[vid], 0, 1);
}

fragment float4 draw() {

    return float4(0.5, 0, 0.5, 1);
}
