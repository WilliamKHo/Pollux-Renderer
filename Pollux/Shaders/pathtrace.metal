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
#include "mis_helper_header.metal"

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
    
    //Naive Early Ray Termination
    // TODO: Stream Compact and remove this line
    if (ray.idx_bounces[2] <= 0) {return;}
    
    device Intersection& intersection = intersections[position];
    getIntersection(ray, geoms, intersection, geom_count);
}


/// Shade
kernel void kern_ShadeMaterials(constant   uint& ray_count             [[ buffer(0) ]],
                                constant   uint& iteration             [[ buffer(1) ]],
                                device     Ray* rays                   [[ buffer(2) ]],
                                device     Intersection* intersections [[ buffer(3) ]],
                                device     Geom*         geoms         [[ buffer(4)]],
                                device     Material*     materials     [[ buffer(5) ]],
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
    int pixel = ray.idx_bounces[0] + 1280 * ray.idx_bounces[1];
    accumulated[pixel] += float4(ray.color, 1.f);
    
    float4 normalized = accumulated[pixel] / (iteration + 1.0);
    
    drawable.write(normalized, ray.idx_bounces.xy);
}

// Shade with MIS
kernel void kern_ShadeMaterialsMIS(constant   uint& ray_count             [[ buffer(0) ]],
                                   constant   uint& iteration             [[ buffer(1) ]],
                                   device     Ray* rays                   [[ buffer(2) ]],
                                   device     Intersection* intersections [[ buffer(3) ]],
                                   device     Geom*         geoms         [[ buffer(4)]],
                                   device     Material*     materials     [[ buffer(5) ]],
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
        if (m.bsdf == -1) {
            //light the ray
            ray.color *= (m.color * m.emittance);
            ray.idx_bounces[2] = 0;
            return;
        }
        
        // Seed a random number from the position and iteration number
        Loki rng = Loki(position, iteration + 1, ray.idx_bounces[2] + 1);
        
        /*
        * Light Importance Sampling
        */
        int lightId = 0; // TODO: Make useful for multiple lights
        device Geom& light = geoms[lightId];
        device Material& light_m = materials[light.materialid];
        thread float pdf_li;
        thread Ray lightRay = ray;
        
        lightRay.origin = intersection.point + intersection.normal * EPSILON;
        float3 lightContribution = sample_li(light, light_m, intersection.point, rng, lightRay.direction, pdf_li);
        
        thread Intersection lightIntersection = intersection;
        
        getIntersection(lightRay, geoms, lightIntersection, 7); //TODO: replace with light count
        
        if (lightIntersection.t > 0.f && lightIntersection.materialId != light.materialid) lightContribution = float3(0);
        
        lightContribution *= dot(intersection.normal, lightRay.direction) * m.color * ray.color; //TODO: Calculate weight using power heuristic
        lightContribution = float3(max(0.f,lightContribution.x), max(0.f,lightContribution.y), max(0.f,lightContribution.z));
        
        /*
         * BSDF Importance Sampling
         */
        
        thread float pdf_bsdf;
        thread Ray bsdfRay;
        bsdfRay.color = float3(1);
        bsdfRay.origin = intersection.point + intersection.normal * EPSILON ;
        scatterRay(bsdfRay, intersection, m, rng, pdf_bsdf);
        thread Intersection bsdfIntersection = intersection;
        getIntersection(bsdfRay, geoms, bsdfIntersection, 7);

        // Only add contribution if it's a light
        if (bsdfIntersection.t > 0.f && bsdfIntersection.materialId == light.materialid) {
            // Assumption: There's a single light material
            bsdfRay.color = m.color * light_m.emittance * ray.color * dot(intersection.normal, bsdfRay.direction);
            bsdfRay.color = float3(max(0.f, bsdfRay.color.x), max(0.f, bsdfRay.color.y), max(0.f, bsdfRay.color.z));
        }
        float nf = 1.f, gf = 1.f;
        float dlWeight = powerHeuristic(nf, pdf_li, gf, pdf_bsdf);
        float bsdfWeight = powerHeuristic(nf, pdf_bsdf, gf, pdf_li);
        
        //Ray for next iteration
        ray.color = (lightContribution * pdf_li + bsdfRay.color * pdf_bsdf) * 0.5;
        scatterRay(ray, intersection, m, rng, pdf);
    }
    else { // If there was no intersection, color the ray black.
        // TODO: Environment Map Code goes here
        //       something like: ray.color = getEnvMapColor(ray.direction);
        ray.color = float3(0);
        ray.idx_bounces[2] = 0;
    }
}



