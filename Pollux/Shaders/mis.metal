//
//  mis.metal
//  Pollux
//
//  Created by William Ho on 12/4/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../Data_Types/PolluxTypes.h"
#import  "Loki/loki_header.metal"
#include "intersections_header.metal"
#include "interactions_header.metal"
#include "mis_helper_header.metal"

using namespace metal;

// Shade with MIS
kernel void kern_ShadeMaterialsMIS(constant   uint& ray_count             [[ buffer(0) ]],
                                   constant   uint& iteration             [[ buffer(1) ]],
                                   device     Ray* rays                   [[ buffer(2) ]],
                                   device     Intersection* intersections [[ buffer(3) ]],
                                   constant   Material*     materials     [[ buffer(4) ]],
                                   texture2d<float, access::sample> environment [[ texture(5) ]],
                                   constant    float3& envEmittance       [[ buffer(6) ]],
                                   constant    bool& envMapFlag           [[ buffer(7) ]],
                                   constant   Geom*         geoms         [[ buffer(8) ]],
                                   constant   uint&         geom_count    [[ buffer(9) ]],
                                   constant   uint&         light_count   [[ buffer(10) ]],
                                   const uint position [[thread_position_in_grid]]) {
    
    if (position >= ray_count) {return;}
    Intersection intersection = intersections[position];
    device Ray& ray = rays[position];
    
    //Naive Early Ray Termination
    // TODO: Stream Compact and remove this line
    if (ray.idx_bounces[2] <= 0) {return;}


    if (intersection.t < ZeroEpsilon) { // If there was no intersection, color the ray black.
        if (envMapFlag && ray.idx_bounces[2] >= 1) { ray.color += getEnvironmentColor(environment, ray) * envEmittance; }
        else { ray.color = float3(0); }
        ray.idx_bounces[2] = 0;
        return;
    }


    // if the intersection exists...
    Material intersection_m = materials[intersection.materialId];

    // If the material indicates that the object was a light, "light" the ray
    if (intersection_m.emittance.x > ZeroEpsilon ||
        intersection_m.emittance.y > ZeroEpsilon ||
        intersection_m.emittance.z > ZeroEpsilon) {
        // This assumes that the light's contribution is equal in all directions
        // i.e. it is a flat color
        ray.color += (intersection_m.color * intersection_m.emittance);
        ray.idx_bounces[2] = 0;
        return;
    }

    // Seed a random number from the position and iteration number
    Loki rng = Loki(position, iteration + 1, ray.idx_bounces[2] + 1);

    /*************************************************************
     ******* Bounce the ray off to add the GI contribution *******
     *************************************************************/

    //Store a copy. We only add this in the end.
    thread Ray gi_Component = ray;
    gi_Component.color = float3(1);
    float gi_pdf;
    // If the material indicates that the object was a light, "light" the ray
    shadeAndScatter(gi_Component, intersection, intersection_m, rng, gi_pdf);
    
    ray.specularBounce = isSpecular(intersection_m);

    //At this point, we've scattered, sampled and gi_component now has a new direction and origin.
    //            \      ^
    //             \    /
    //              \  /     <---- gi_Component
    //               \/
    //

    if (!ray.specularBounce) {
        // Light from both light-based sampling and BSDF based sampling:
        float3 combined_light = float3(0);

        /*************************************************************
         ****************** Light Importance Sampling ****************
         *************************************************************/

        // Pick a random light
        const int lightId = rng.rand() * light_count;
        // Get that light from the geoms buffer, assuming lights
        // are the first `light_count` geoms
        constant Geom& light = geoms[lightId];
        // Get Light Material
        constant Material& light_m = materials[light.materialid];

        // Set the wo to be the opposite of ray.direction
        const    float3 wo = -ray.direction;

        // Initialize values to be filled in during `sample_li`
        thread float3 wi;
        thread float pdf_li;

        // At this point, intersection.point is overwritten to mean the intersection
        // on the light
        float3 li_x = sample_li(light, light_m, intersection.point, rng, wi, pdf_li);
        if (abs(pdf_li) > ZeroEpsilon) {
            // Check if there is something in the way, zero out if there is something in the way
            Ray direct_light;
            direct_light.origin    = intersection.point + intersection.normal * EPSILON;
            direct_light.direction = wi;

            // An intersection point that determines if the point is shadowed
            Intersection shadow_isect = getIntersection(direct_light, geoms, geom_count);

            // zero out contribution if it doesn't hit anything
            // TODO: Modify this to work using shadow_isect.objectHit and not materialId
            // this makes the code more robust
            const bool shadowed = shadow_isect.t > ZeroEpsilon && (shadow_isect.materialId != light.materialid);
            li_x = shadowed ? float3(0) : li_x;

            const float pdf_bsdf = pdf(intersection_m.bsdf, wo, -wi, intersection.normal);

            // The lights color  * lambert term
            const float3 f_x = f(intersection_m, wi, wo) * abs(dot(-wi, intersection.normal));

            const float weight_li = powerHeuristic(1, pdf_li, 1, pdf_bsdf);

            combined_light = (f_x * li_x * weight_li * ray.throughput)
                                          / (pdf_li);
            
            combined_light *= light_count;
            
            ray.color += combined_light;
            ray.idx_bounces[2] = 0;
            return;
        }

        /*************************************************************
         ****************** BSDF Importance Sampling *****************
         *************************************************************/

//        thread float pdf_bsdf;
//        thread Ray bsdfRay = ray;
//        bsdfRay.color = float3(1);
//        shadeAndScatter(bsdfRay, intersection, intersection_m, rng, pdf_bsdf);
//        float3 f_y = intersection_m.color;
//        thread Intersection bsdfIntersection = getIntersection(bsdfRay, geoms, geom_count);
//        float3 bsdfContribution = float3(0);
//        if (bsdfIntersection.t > 0.f && bsdfIntersection.materialId == light.materialid) {
//            bsdfContribution = f_y * bsdfRay.color * ray.throughput;
//        }
//
//        float nf = 1.f, gf = 1.f;
//        float dlWeight = powerHeuristic(nf, pdf_li, gf, pdf_bsdf);
//        float bsdfWeight = powerHeuristic(nf, pdf_bsdf, gf, pdf_li);
    }

    //Ray for next iteration
//    ray.color +=  (lightContribution * dlWeight + bsdfContribution * bsdfWeight) * light_count;
//    ray.throughput *= gi_Component.color;
//    ray.origin = gi_Component.origin;
//    ray.direction = gi_Component.direction;
//    ray.idx_bounces[2]--;
}

// Shade with Direct Lighting (Single Bounce)
kernel void kern_ShadeMaterialsDirect(constant   uint& ray_count             [[ buffer(0) ]],
                                      constant   uint& iteration             [[ buffer(1) ]],
                                      device     Ray* rays                   [[ buffer(2) ]],
                                      device     Intersection* intersections [[ buffer(3) ]],
                                      constant   Material*     materials     [[ buffer(4) ]],
                                      texture2d<float, access::sample> environment [[ texture(5) ]],
                                      constant   float3& envEmittance        [[ buffer(6) ]],
                                      constant   bool& envMapFlag            [[ buffer(7) ]],
                                      constant   Geom*         geoms         [[ buffer(8) ]],
                                      constant   uint&         geom_count    [[ buffer(9) ]],
                                      constant   uint&         light_count   [[ buffer(10) ]],
                                      const uint position [[thread_position_in_grid]]) {
    
    if (position >= ray_count) {return;}
    Intersection intersection = intersections[position];
    device Ray& ray = rays[position];
    
    //Naive Early Ray Termination
    // TODO: Stream Compact and remove this line
    if (ray.idx_bounces[2] <= 0) {return;}
    
    
    if (intersection.t < ZeroEpsilon) { // If there was no intersection, color the ray black.
        if (envMapFlag && ray.idx_bounces[2] >= 1) { ray.color *= getEnvironmentColor(environment, ray) * envEmittance; }
        else { ray.color = float3(0); }
        ray.idx_bounces[2] = 0;
        return;
    }
    
    
    // if the intersection exists...
    Material intersection_m = materials[intersection.materialId];
    
    // If the material indicates that the object was a light, "light" the ray
    if (intersection_m.emittance.x > ZeroEpsilon ||
        intersection_m.emittance.y > ZeroEpsilon ||
        intersection_m.emittance.z > ZeroEpsilon) {
        // This assumes that the light's contribution is equal in all directions
        // i.e. it is a flat color
        ray.color += (intersection_m.color * intersection_m.emittance);
        ray.idx_bounces[2] = 0;
        return;
    }
    
    // Seed a random number from the position and iteration number
    Loki rng = Loki(position, iteration + 1, ray.idx_bounces[2] + 1);
    
    if (!ray.specularBounce) {
        // Light from both light-based sampling and BSDF based sampling:
        float3 combined_light = float3(0);
        
        /*************************************************************
         ****************** Light Importance Sampling ****************
         *************************************************************/
        
        // Pick a random light
        const int lightId = rng.rand() * light_count;
        // Get that light from the geoms buffer, assuming lights
        // are the first `light_count` geoms
        constant Geom& light = geoms[lightId];
        // Get Light Material
        constant Material& light_m = materials[light.materialid];
        
        // Set the wo to be the opposite of ray.direction
        const    float3 wo = -ray.direction;
        
        // Initialize values to be filled in during `sample_li`
        thread float3 wi;
        thread float pdf_li;
        
        // At this point, intersection.point is overwritten to mean the intersection
        // on the light
        float3 li_x = sample_li(light, light_m, intersection.point, rng, wi, pdf_li);
        if (abs(pdf_li) > ZeroEpsilon) {
            // Check if there is something in the way, zero out if there is something in the way
            Ray direct_light;
            direct_light.origin    = intersection.point + intersection.normal * EPSILON;
            direct_light.direction = wi;
            
            // An intersection point that determines if the point is shadowed
            Intersection shadow_isect = getIntersection(direct_light, geoms, geom_count);
            
            // zero out contribution if it doesn't hit anything
            // TODO: Modify this to work using shadow_isect.objectHit and not materialId
            // this makes the code more robust
            const bool shadowed = shadow_isect.t > ZeroEpsilon && (shadow_isect.materialId != light.materialid);
            li_x = shadowed ? float3(0) : li_x;
            
            // The lights color  * lambert term
            const float3 f_x = f(intersection_m, wi, wo) * abs(dot(-wi, intersection.normal));
            
            combined_light = (f_x * li_x)
                            /  pdf_li;
            
            combined_light *= light_count;
            
            ray.color = combined_light;
            ray.idx_bounces[2] = 0;
            return;
        }
    }
}


