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
                                  constant uint& iteration [[ buffer(3) ]],
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
        
        // Random Number Generator
        Loki rng = Loki(position.x + position.y, iteration + 1, ray.idx_bounces[2] + 1);
        
        ray.direction = normalize(cam.view  - cam.right * pixelLength.x * ((float)x -  width  * 0.5f + (rng.rand() * AA_SIZE))
                                            - cam.up    * pixelLength.y * ((float)y -  height * 0.5f + (rng.rand() * AA_SIZE)));
        
        //use u and v along with the lensradius to determine a new segment origin
        float focalDistance = cam.lensData[1];
        float dofRadius = cam.lensData[0] * rng.rand();
        float dofTheta = PI * 2.0f * rng.rand();
        
        float dof_x = sqrt(dofRadius) * cos(dofTheta);
        float dof_y = sqrt(dofRadius) * sin(dofTheta);
        
        //determine where the ray would intersect the focal plane normally
        float3 focalPoint = ray.origin + (focalDistance * (1.0f / dot(ray.direction, normalize(cam.view)))) * ray.direction;
        
        //make the ray originate from the new origin and pass through the point on the focal plane
        ray.origin += dof_x * cam.right + dof_y * cam.up;
        ray.direction = normalize(focalPoint - ray.origin);
        
        
        // Set ray values
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
                                      constant float* kdtrees              [[ buffer(5) ]],
                                      const uint position [[thread_position_in_grid]]) {
    
    if (position >= ray_count){ return;}
    
    const Ray ray = rays[position];
    
    // Get the Intersection
    intersections[position] = getIntersection(ray, kdtrees, geoms, geom_count);
}


/// Shade
kernel void kern_ShadeMaterialsNaive(constant   uint& ray_count             [[ buffer(0) ]],
                                     constant   uint& iteration             [[ buffer(1) ]],
                                     device     Ray* rays                   [[ buffer(2) ]],
                                     device     Intersection* intersections [[ buffer(3) ]],
                                     constant   Material*     materials     [[ buffer(4) ]],
                                     // Environment Map
                                     texture2d<float, access::sample> environment [[ texture(5) ]],
                                     constant    float3& envEmittance             [[ buffer(6) ]],
                                     const uint position [[thread_position_in_grid]]) {
    
    if (position >= ray_count) {return;}
    
    Intersection intersection = intersections[position];
    device Ray& ray = rays[position];
    
    // Naive Early Ray Termination:- Stream Compaction Should be Done Here
    if (ray.idx_bounces[2] <= 0) {return;}
    
    if (intersection.t > 0.0f) { // if the intersection exists...
        Material m = materials[intersection.materialId];
        
        // If the material indicates that the object was a light, "light" the ray
        thread float pdf;
        
        // Seed a random number from the position and iteration number
        Loki rng = Loki(position, iteration + 1, ray.idx_bounces[2] + 1);
        
        thread Ray thread_ray = ray;
        shadeAndScatter(thread_ray, intersection, m, rng, pdf);
        ray = thread_ray;
    }
    else {
        // If the environment emittance is zero or the environment doesn't exist, then it returns zero.
        ray.color *= getEnvironmentColor(environment, envEmittance, ray.direction);
        ray.idx_bounces[2] = 0;
    }
}

//// Evaluate rays for early termination using stream compaction
//kernel void kern_EvaluateRays(constant      uint& ray_count         [[  buffer(0)  ]],
//                              device        uint* validation_buffer [[  buffer(1)  ]],
//                              const device  Ray *rays               [[  buffer(2)  ]],
//                              const uint id [[thread_position_in_grid]]) {
//    // Quicker and clean.
//    validation_buffer[id] = (id < ray_count && rays[id].idx_bounces[2] > 0) ? 1 : 0;
//}

constant float vignetteStart = 0.6f;
constant float vignetteEnd   = 1.f;

float3 toneMap(const thread float3& in) {
        return ((in*(0.35f*in + 0.10f*0.50f) + 0.20f*0.02f) / (in*(0.35f*in + 0.50f) + 0.20f*0.10f)) - 0.02f / 0.10f;
}


/// Final Gather
kernel void kern_FinalGather(constant   uint& ray_count                   [[  buffer(0) ]],
                             constant   uint& iteration                   [[  buffer(1) ]],
                             device     Ray* rays                         [[  buffer(2) ]],
                             device     float4* accumulated               [[  buffer(3) ]],
                             constant   Camera& camera                    [[  buffer(4) ]],
                             texture2d<float, access::write> drawable     [[ texture(4) ]],
                             const uint position [[thread_position_in_grid]]) {
    
    if (position >= ray_count) {return;}
    device Ray& ray = rays[position];

    accumulated[position] += float4(ray.color,1.0);
    
    float4 normalized = accumulated[position] / (iteration + 1.0);
    
   // Reinhardt filmic tonemapping
   float maxDistance = max(camera.data.x, camera.data.y);
   float2 uv = float2(ray.idx_bounces.x - camera.data.x * .5f, ray.idx_bounces.y - camera.data.y * .5f);
   uv /= maxDistance;
   
   float vignette = 1.0 - smoothstep(vignetteStart, vignetteEnd, length(uv) / 0.70710678118f);
   
   float4 pixel = normalized;
   
   // Divide by accumulated filter weight
   pixel /= pixel.w;
   
   // Exposure
   pixel *= 2.0 * vignette;
   
   // Custom vignette operator
   pixel = mix(pixel * pixel * .5f, pixel, vignette);
   
   float3 current = toneMap(float3(pixel));
   float3 whiteScale = 1.0f / toneMap(float3(13.2f));
   float3 color = clamp(current*whiteScale, float3(0.f), float3(1.f));
   
   pixel.xyz = float3(pow(color, 1 /2.2f));
   
   normalized = mix(pixel, normalized, 0.5);
    
    drawable.write(normalized, ray.idx_bounces.xy);
    
    // DEBUG: COMMENT THIS OUT:
//    float3 debug_color = float3(min(ray.idx_bounces[2], unsigned(1)));
//    Loki rng = Loki(threadGroupId);
//    float3 color = float3(block_sums[threadGroupId/4] / 1280.0);
//    float3 color = float3(validation_buffer[position] / 64.0);
//    color = color.x > 1 ? float3(color.x / 100000,0,0) : color;
//    drawable.write(float4(0,0,0,1), ray.idx_bounces.xy);
}



