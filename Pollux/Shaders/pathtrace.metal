//
//  pathtrace.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/7/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../SceneParameters.h"
#include "../Data_Types/PolluxTypes.h"
#include "Loki/loki_header.metal"
#include "intersections_header.metal"
#include "interactions_header.metal"

using namespace metal;

kernel void kern_GenerateRaysFromCamera(constant Camera& cam [[ buffer(0) ]],
                                  constant uint& traceDepth [[ buffer(1) ]] ,
                                  device Ray* rays [[ buffer(2) ]] ,
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
        device Ray& ray = rays[index];
        
        ray.origin = cam.pos;
        
        if (integrator == "MIS") {
            ray.color = float3(0.f);
            ray.throughput = float3(1.f);
        } else {
            ray.color = float3(1.f);
        }
        
        // Calculations for ray cast:
        const float yscaled = tan(fov * (3.14159 / 180));
        const float xscaled = (yscaled * width) / height;
        const float2 pixelLength = float2(2 * xscaled / (float)width
                                    , 2 * yscaled / (float)height);
        
        
        // TODO: implement antialiasing by jittering the ray
        ray.direction = normalize(cam.view
                                               - cam.right * pixelLength.x * ((float)x -  width  * 0.5f)
                                               - cam.up    * pixelLength.y * ((float)y -  height * 0.5f)
                                               );
        
        ray.idx_bounces.x = x;
        ray.idx_bounces.y = y;
        ray.idx_bounces[2] = traceDepth;
        ray.specularBounce = 0;
    }
}

/// Compute Intersections
kernel void kern_ComputeIntersections(constant uint& ray_count             [[ buffer(0) ]],
                                      constant uint& geom_count            [[ buffer(1) ]],
                                      constant Ray* rays                   [[ buffer(2) ]],
                                      device   Intersection* intersections [[ buffer(3) ]],
                                      constant Geom* geoms                 [[ buffer(4) ]],
                                      const uint position [[thread_position_in_grid]]) {
    
    if (position >= ray_count){ return;}
    
    const Ray ray = rays[position];
    
    // Get the Intersection
    intersections[position] = getIntersection(ray, geoms, geom_count);
}


/// Shade
kernel void kern_ShadeMaterialsNaive(constant   uint& ray_count             [[ buffer(0) ]],
                                constant   uint& iteration             [[ buffer(1) ]],
                                device     Ray* rays                   [[ buffer(2) ]],
                                device     Intersection* intersections [[ buffer(3) ]],
                                constant     Material*     materials     [[ buffer(4) ]],
                                texture2d<float, access::sample> environment [[ texture(5) ]],
                                constant    float3& envEmittance        [[ buffer(6) ]],
                                constant    bool& envMapFlag            [[ buffer(7) ]],
                                const uint position [[thread_position_in_grid]]) {
    
    if (position >= ray_count) {return;}
    
    Intersection intersection = intersections[position];
    device Ray& ray = rays[position];
    
    //Naive Early Ray Termination
    // TODO: Stream Compact and remove this line
    if (ray.idx_bounces[2] <= 0) {return;}
    // DEBUG CHECK THIS NOT BAD
    
    if (intersection.t > 0.0f) { // if the intersection exists...
        Material m = materials[intersection.materialId];
        
        // If the material indicates that the object was a light, "light" the ray
        thread float pdf;
        
        // Seed a random number from the position and iteration number
        Loki rng = Loki(position, iteration + 1, ray.idx_bounces[2] + 1);
        
        shadeAndScatter(ray, intersection, m, rng, pdf);
    }
    else { // If there was no intersection, color the ray black.
        // TODO: Environment Map Code goes here
        //       something like: ray.color = getEnvMapColor(ray.direction);
        
        if (envMapFlag && ray.idx_bounces[2] > 1) { ray.color *= getEnvironmentColor(environment, ray) * envEmittance; }
        else { ray.color = float3(0); }
        ray.idx_bounces[2] = 0;
    }
}

//// Evaluate rays for early termination using stream compaction
//kernel void kern_EvaluateRays(constant      uint& ray_count         [[  buffer(0)  ]],
//                              device        uint* validation_buffer [[  buffer(1)  ]],
//                              const device  Ray *rays               [[  buffer(2)  ]],
//                              const device  bool *reversed          [[  buffer(9)  ]],
//                              const uint id [[thread_position_in_grid]]) {
//    // Quicker and clean.
//    validation_buffer[id] = (id < ray_count && rays[id].idx_bounces[2] > 0) ? 1 : 0;
//}


/// Final Gather
kernel void kern_FinalGather(constant   uint& ray_count                   [[  buffer(0) ]],
                             constant   uint& iteration                   [[  buffer(1) ]],
                             device     Ray* rays                         [[  buffer(2) ]],
                             device     float4* accumulated               [[  buffer(3) ]],
                             texture2d<float, access::write> drawable     [[ texture(4) ]],
                             const uint position [[thread_position_in_grid]]) {
    // DEBUG: UNCOMMENT THIS TO FIX STUFF:
    if (position >= ray_count) {return;}
    device Ray& ray = rays[position];

    // DEBUG: UNCOMMENT THIS TO FIX STUFF
    float4 ray_col     = float4(ray.color, 1.f);
//    //float4 accumulated = inFrame.read(ray.idx_bounces.xy).rgba;
    accumulated[position] += ray_col;
    
    float4 normalized = accumulated[position] / (iteration + 1.0);
    
    drawable.write(normalized, ray.idx_bounces.xy);
    
    // DEBUG: COMMENT THIS OUT:
//    float3 debug_color = float3(min(ray.idx_bounces[2], unsigned(1)));
//    Loki rng = Loki(threadGroupId);
//    float3 color = float3(block_sums[threadGroupId/4] / 1280.0);
//    float3 color = float3(validation_buffer[position] / 64.0);
//    color = color.x > 1 ? float3(color.x / 100000,0,0) : color;
//    drawable.write(float4(0,0,0,1), ray.idx_bounces.xy);
}



