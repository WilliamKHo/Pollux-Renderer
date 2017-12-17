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
                                   constant   float*         kdtrees      [[ buffer(5) ]],
                                   texture2d<float, access::sample> environment [[ texture(5) ]],
                                   constant   float3& envEmittance        [[ buffer(6) ]],
                                   constant   uint&         max_depth     [[ buffer(7) ]],
                                   constant   Geom*         geoms         [[ buffer(8) ]],
                                   constant   uint&         geom_count    [[ buffer(9) ]],
                                   constant   uint&         light_count   [[ buffer(10) ]],
                                   const uint position [[thread_position_in_grid]]) {
    
    if (position >= ray_count) {return;}
    Intersection intersection = intersections[position];
    device Ray& ray = rays[position];
    
    //Naive Early Ray Termination
    // ----: Stream Compact and remove this line
    // DONE: Not gonna happen.
    if (ray.idx_bounces[2] <= 0) {return;}
    
    if (intersection.t < ZeroEpsilon) { // If there was no intersection, color the ray black.
        ray.color = getEnvironmentColor(environment, envEmittance, ray.direction);
        ray.idx_bounces[2] = 0;
        return;
    }
    
    // if the intersection exists...
    Material intersection_m = materials[intersection.materialId];
    
    if (ray.idx_bounces[2] == max_depth || ray.specularBounce) {
        //405: Assumption: light is emitted equally from/to all directions
        ray.color += ray.throughput * (intersection_m.color * intersection_m.emittance);
    }
    
    // If the material indicates that the object was a light, "light" the ray
    if (intersection_m.emittance.x > ZeroEpsilon ||
        intersection_m.emittance.y > ZeroEpsilon ||
        intersection_m.emittance.z > ZeroEpsilon) {
        // This assumes that the light's contribution is equal in all directions
        // i.e. it is a flat color
        ray.idx_bounces[2] = 0;
        return;
    }
    
    // Seed a random number from the position and iteration number
    Loki rng = Loki(position, iteration + 1, ray.idx_bounces[2] + 1);
    
    /*************************************************************
     ******* Bounce the ray off to add the GI contribution *******
     *************************************************************/
    
    //Store a copy. We only add this in the end.
    thread Ray gi_Component;
    gi_Component.origin = ray.origin;
    gi_Component.direction = ray.direction;
    gi_Component.idx_bounces = ray.idx_bounces;
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
    
    // Pick a random light
    const int lightId = rng.rand() * light_count;
    // Get that light from the geoms buffer, assuming lights
    // are the first `light_count` geoms
    constant Geom& light = geoms[lightId];
    // Get Light Material
    constant Material& light_m = materials[light.materialid];
    
    if (!ray.specularBounce) {
        // Light from both light-based sampling and BSDF based sampling:
        float3 Ld = float3(0);
        
        /*************************************************************
         ****************** Light Importance Sampling ****************
         *************************************************************/
        
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
            Intersection shadow_isect = getIntersection(direct_light, kdtrees, geoms, geom_count);

            // zero out contribution if it doesn't hit anything
            // this makes the code more robust
            const bool shadowed = shadow_isect.t > ZeroEpsilon && (shadow_isect.materialId != light.materialid);
            li_x = shadowed ? float3(0) : li_x;

            const float pdf_bsdf = pdf(intersection_m.bsdf, wo, -wi, intersection.normal);

            // The lights color  * lambert term
            const float3 f_x = f(intersection_m, wi, wo) * abs(dot(-wi, intersection.normal));

            const float weight_li = powerHeuristic(1, pdf_li, 1, pdf_bsdf);

            Ld = (f_x * li_x * weight_li * ray.throughput)
                        / (pdf_li);
        }
    
        /*************************************************************
         ****************** BSDF Importance Sampling *****************
         *************************************************************/
        
        // Get f(X) and L(X)
        Ray indirect_path;
        float bsdf_pdf;
        indirect_path.origin = ray.origin;
        indirect_path.direction = ray.direction;

        indirect_path.color = float3(1.f);
        shadeAndScatter(indirect_path, intersection, intersection_m, rng, bsdf_pdf);

        thread float3 indirect_wi = indirect_path.direction;
        float3 f_y = indirect_path.color;

        // Only do calculations if bsdfpdf is not zero for efficiency
        if (bsdf_pdf > ZeroEpsilon) {
            Intersection bsdf_direct_isx;
            indirect_path.origin = intersection.point + intersection.normal * EPSILON;

            bsdf_direct_isx = getIntersection(indirect_path, kdtrees, geoms, geom_count);


            const float pdf_li = pdfLi(light, intersection.point, indirect_wi);

            //Only add cotribution if object hit is the light
            if ((bsdf_direct_isx.t > ZeroEpsilon) && (bsdf_direct_isx.materialId == light.materialid)) {
                const float weight_bsdf = powerHeuristic(1, bsdf_pdf, 1, pdf_li);

                const float3 li_y = light_m.emittance * light_m.color;

                Ld += li_y * f_y * weight_bsdf * ray.throughput;
            }
        }

        Ld *= light_count;

        //****************************************
        //**Add Ld to Ray color before GI Stuff***
        //****************************************
        ray.color += Ld;
    }

    //Update Scene_Ray - This just spawns a new ray for the next loop
    ray.origin      = gi_Component.origin;
    ray.direction   = gi_Component.direction;
    ray.idx_bounces = gi_Component.idx_bounces;
    ray.throughput *= gi_Component.color;
    ray.specularBounce = isSpecular(intersection_m);
    
    
    if ((gi_Component.color.x < ZeroEpsilon &&
         gi_Component.color.y < ZeroEpsilon &&
         gi_Component.color.z < ZeroEpsilon) ||
        (intersection.materialId == light.materialid)) {
        ray.idx_bounces[2] = 0;
        return;
    }
    
    //Russian Roulette Early Ray Termination
    if (max_depth - ray.idx_bounces[2] >= 3) {
        const float q = max(0.05f, (1 - max(ray.throughput.x, max(ray.throughput.y, ray.throughput.z))));
        if (rng.rand() < q) {
            ray.idx_bounces[2] = 0;
            return;
        }
        ray.throughput /= (1 - q);
    }
}

// Shade with Direct Lighting (Single Bounce)
kernel void kern_ShadeMaterialsDirect(constant   uint& ray_count             [[ buffer(0) ]],
                                      constant   uint& iteration             [[ buffer(1) ]],
                                      device     Ray* rays                   [[ buffer(2) ]],
                                      device     Intersection* intersections [[ buffer(3) ]],
                                      constant   Material*     materials     [[ buffer(4) ]],
                                      constant   float*        kdtrees       [[ buffer(5) ]],
                                      texture2d<float, access::sample> environment [[ texture(5) ]],
                                      constant   float3& envEmittance        [[ buffer(6) ]],
                                      constant   Geom*         geoms         [[ buffer(8) ]],
                                      constant   uint&         geom_count    [[ buffer(9) ]],
                                      constant   uint&         light_count   [[ buffer(10) ]],
                                      const uint position [[thread_position_in_grid]]) {

    if (position >= ray_count) {return;}
    Intersection intersection = intersections[position];
    device Ray& ray = rays[position];

    // Naive Early Ray Termination: Stream Compaction should render this useless
    if (ray.idx_bounces[2] <= 0) {return;}

    if (intersection.t < ZeroEpsilon) { // If there was no intersection, color the ray black.
        ray.color *= getEnvironmentColor(environment, envEmittance, ray.direction);
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

        // At this point, we get a random point on the light using sample_li
        float3 li_x = sample_li(light, light_m, intersection.point, rng, wi, pdf_li);
        if (abs(pdf_li) > ZeroEpsilon) {
            // Check if there is something in the way, zero out if there is something in the way
            Ray direct_light;
            direct_light.origin    = intersection.point + intersection.normal * EPSILON;
            direct_light.direction = wi;

            // An intersection point that determines if the point is shadowed
            Intersection shadow_isect = getIntersection(direct_light, kdtrees, geoms, geom_count);


            // zero out contribution if it doesn't hit anything or if we hit something other than the light
            const bool shadowed = shadow_isect.t > ZeroEpsilon && (shadow_isect.materialId != light.materialid);
            li_x = shadowed ? float3(0) : li_x;

            // The lights color  * lambert term
            const float3 f_x = f(intersection_m, wi, wo) * abs(dot(-wi, intersection.normal));

            combined_light = (f_x * li_x)
                              / pdf_li;

            combined_light *= light_count;

            ray.color = combined_light;
            ray.idx_bounces[2] = 0;
            return;
        }
    }
}



