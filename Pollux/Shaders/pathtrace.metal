//
//  pathtrace.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/7/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../Data_Types/PolluxTypes.h"
#import  "Loki/loki_header.metal"
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
        ray.color = float3(1.0f, 1.0f, 1.0f);
        
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
        ray.uv.x = x / width;
        ray.uv.y = y / height;
    }
}

/// Compute Intersections
kernel void kern_ComputeIntersections(constant uint& ray_count             [[ buffer(0) ]],
                                      constant uint& geom_count            [[ buffer(1) ]],
                                      device   Ray* rays                   [[ buffer(2) ]],
                                      device   Intersection* intersections [[ buffer(3) ]],
                                      device   Geom* geoms                 [[ buffer(4) ]],
                                      const uint position [[thread_position_in_grid]]) {
    
    if (position >= ray_count){ return;}
    
    thread Ray ray = rays[position];
    
    float t;
    float3 intersect_point;
    float3 normal;
    float t_min = FLT_MAX;
    int hit_geom_index = -1;
    bool outside = true;
    
    float3 tmp_intersect;
    float3 tmp_normal;
    
    // naive parse through global geoms
    for (uint i = 0; i < geom_count; i++)
    {
        device Geom& geom = geoms[i];
        
        if (geom.type == CUBE)
        {
            t = computeCubeIntersection(&geom, ray, tmp_intersect, tmp_normal, outside);
        }
        else if (geom.type == SPHERE)
        {
            t = computeSphereIntersection(&geom, ray, tmp_intersect, tmp_normal, outside);
        }
        // TODO: add more intersection tests here... triangle? metaball? CSG?
        
        // Compute the minimum t from the intersection tests to determine what
        // scene geometry object was hit first.
        if (t > 0.0f && t_min > t)
        {
            t_min = t;
            hit_geom_index = i;
            intersect_point = tmp_intersect;
            normal = tmp_normal;
        }
    }
    
    device Intersection& intersection = intersections[position];
    
    if (hit_geom_index == -1)
    {
        // The ray doesn't hit something (index == -1)
        intersection.t = -1.0f;
    }
    else
    {
        //The ray hits something
        intersection.t = t_min;
        intersection.materialId = geoms[hit_geom_index].materialid;
        intersection.normal = normal;
        intersection.point = intersect_point;
    }
}


/// Shade
kernel void kern_ShadeMaterials(constant   uint& ray_count             [[ buffer(0) ]],
                                constant   uint& iteration             [[ buffer(1) ]],
                                device     Ray* rays                   [[ buffer(2) ]],
                                device     Intersection* intersections [[ buffer(3) ]],
                                device     Material*     materials     [[ buffer(4) ]],
                                // TODO: Delete buffers 5 & 6 for later stages
                                texture2d<float, access::write> outTexture [[texture(5)]],
                                constant uint2& imageDeets  [[ buffer(6) ]],
                                // TODO: END DELETE
                                const uint position [[thread_position_in_grid]]) {
    
    if (position >= ray_count) {return;}
    
    Intersection intersection = intersections[position];
    device Ray& ray = rays[position];
    
    //Naive Early Ray Termination
    // TODO: Stream Compact and remove this line
    if (ray.idx_bounces[2] <= 0) {return;}
    
    if (intersection.t > 0.0f) { // if the intersection exists...
        Material m = materials[intersection.materialId];
        
        // If the material indicates that the object was a light, "light" the ray
        thread float pdf;
        
        // Seed a random number from the position and iteration number
        Loki rng = Loki(position, iteration + 1, ray.idx_bounces[2] + 1);
        
        // TODO: Once I fix Loki's `next_rng()` function, we won't need `random`
        //       as a parameter
        shadeAndScatter(ray, intersection, m, rng, pdf);
    }
    else { // If there was no intersection, color the ray black.
        // TODO: Environment Map Code goes here
        //       something like: ray.color = getEnvMapColor(ray.direction);
        ray.color = float3(0);
        ray.idx_bounces[2] = 0;
    }
}

// Evaluate rays for early termination using stream compaction
kernel void kern_EvaluateRays(constant      uint& ray_count         [[  buffer(0)  ]],
                              device        uint* validation_buffer [[  buffer(1)  ]],
                              const device  Ray *rays               [[  buffer(2)  ]],
                              uint id [[thread_position_in_grid]]) {
    // Quicker and clean.
    validation_buffer[id] = (id >= ray_count) ? 0 : int(rays[id].idx_bounces[2] > 0);
}


/// Final Gather
kernel void kern_FinalGather(constant   uint& ray_count                   [[  buffer(0) ]],
                             constant   uint& iteration                   [[  buffer(1) ]],
                             device     Ray* rays                         [[  buffer(2) ]],
                             device     float4* accumulated               [[  buffer(3) ]],
                             texture2d<float, access::write> drawable     [[ texture(4) ]],
                             const uint position [[thread_position_in_grid]]) {
    if (position >= ray_count) {return;}
    
    device Ray& ray = rays[position];
    
//    float4 ray_col     = float4(ray.color, 1.f);
//    float4 accumulated = inFrame.read(ray.idx_bounces.xy).rgba;
//    accumulated[position] += float4(ray.color, 1.f);
    
//    float4 normalized = accumulated[position] / (iteration + 1.0);
    
    float3 debug_color = float3(min(ray.idx_bounces[2], unsigned(1)));
    
    drawable.write(float4(debug_color,1), ray.idx_bounces.xy);
}



