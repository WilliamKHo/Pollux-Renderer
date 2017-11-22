//
//  pathtrace.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/7/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../Data_Types/PolluxTypes.h"
#include "intersections_header.metal"
#import  "Loki/loki_header.metal"

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
        
        ray.idx_bounces[0] = index;
        ray.idx_bounces[1] = traceDepth;
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
        intersection.t = -1.0f;
    }
    else
    {
        //The ray hits something
        intersection.t = t_min;
        intersection.materialId = geoms[hit_geom_index].materialid;
        intersection.normal = normal;
    }
}


/// Shade
//constant uint& ray_count             [[ buffer(0) ]],
//constant uint& geom_count            [[ buffer(1) ]],
//device   Ray* rays                   [[ buffer(2) ]],
//device   Geom* geoms                 [[ buffer(3) ]],
//device   Intersection* intersections [[ buffer(4) ]]
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
    if (intersection.t > 0.0f) { // if the intersection exists...
        // Set up the RNG
       // float random = rng(iteration, position);
        
        Material m = materials[intersection.materialId];
        
        // If the material indicates that the object was a light, "light" the ray
        float pdf;
        //scatterRay(ray, intersection, m, rng, pdf);
    }
    else { // If there was no intersection, color the ray black.
        ray.color = float3(0);
        ray.idx_bounces[1] = 0;
    }
    
    //Get RNG
    float random = Loki::rng(position);
//    random = Loki::rng();
    
    // TODO: Remove this. Just a debug view for this stage
    int x = position % imageDeets.x;
    int y = position / imageDeets.x;
    outTexture.write(float4(float3(abs(random)), 1) , uint2(x,y));
    // TODO: End Remove
}


/// Final Gather
kernel void kern_FinalGather(uint2 position [[thread_position_in_grid]]) {
    
}



