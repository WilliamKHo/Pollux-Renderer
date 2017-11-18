//
//  pathtrace.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/7/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "PolluxTypes.h"

using namespace metal;

kernel void kern_GenerateRaysFromCamera(constant Camera& cam [[ buffer(0) ]],
                                  constant uint& traceDepth [[ buffer(1) ]] ,
                                  device Ray* rays [[ buffer(2) ]] ,
                                  texture2d<float, access::write> outTexture [[texture(3)]],
                                  const uint2 position [[thread_position_in_grid]])
{
    const int x = position.x;
    const int y = position.y;
    
    const int width = cam.data.x;
    const int height = cam.data.y;
    
    const float fov = cam.data[2];
    
    if (x < width && y < height) {
        int index = x + (y * width);
        
        // Get the ray, define that it's on the device.
        device Ray& segment = rays[index];
        
        segment.origin = cam.pos;
        segment.color = float3(1.0f, 1.0f, 1.0f);
        
        // Calculations for ray cast:
        const float yscaled = tan(fov * (3.14159 / 180));
        const float xscaled = (yscaled * width) / height;
        const float2 pixelLength = float2(2 * xscaled / (float)width
                                    , 2 * yscaled / (float)height);
        
        // TODO: implement antialiasing by jittering the ray
        segment.direction = normalize(cam.view
                                               - cam.right * pixelLength.x * ((float)x -  width  * 0.5f)
                                               - cam.up    * pixelLength.y * ((float)y -  height * 0.5f)
                                               );
        
        segment.idx_bounces[0] = index;
        segment.idx_bounces[1] = traceDepth;
        outTexture.write(float4(abs(segment.direction), 1) , position);
    }
}


/// Compute Intersections
kernel void kern_ComputeIntersections(uint2 position [[thread_position_in_grid]]) {
    
}


/// Shade
kernel void kern_ShadeMaterials(uint2 position [[thread_position_in_grid]]) {
    
}


/// Final Gather
kernel void kern_FinalGather(uint2 position [[thread_position_in_grid]]) {
    
}



