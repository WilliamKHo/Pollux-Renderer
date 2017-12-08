//
//  interactions.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/22/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include "interactions_header.metal"

using namespace metal;


void shadeAndScatter(device Ray& ray,
                     thread Intersection& isect,
                     thread Material &m,
                     thread Loki& rng,
                     thread float& pdf) {
    switch (m.bsdf) {
        case -1:
            // Light Shade and 'absorb' ray by terminating
            ray.color *= (m.color * m.emittance);
            ray.idx_bounces[2] = 0;
            break;
        case 0:
            SnS_diffuse(ray, isect, m, rng, pdf);
            break;
        case 1:
            SnS_reflect(ray, isect, m, rng, pdf);
            break;
        case 2:
            SnS_refract(ray, isect, m, rng, pdf);
            break;
        case 3:
            SnS_subsurface(ray, isect, m, rng, pdf);
            break;
        default:
            break;
    }
}


float3 sampleCube(constant Geom&       light,
                  const thread float3&   ref,
                  thread Loki&           rng,
                  thread float3&          wi,
                  thread float&          pdf){
    
    //Get a sample point
    float3 sample_li = float3(rng.rand() - 0.5f, 0, rng.rand() - 0.5f);
    sample_li = float3(light.transform * float4(sample_li, 1));
    
    const float3 normal_li = float3(0, 0, -1);
    
    wi = normalize(sample_li - ref);
    
    //Get shape area and convert it to Solid angle
    const float cosT = fabs(dot(-wi, normal_li));
    const float solid_angle = (length_squared(sample_li - ref) / cosT);
    const float cubeArea = 2 * light.scale.x * light.scale.y *
    2 * light.scale.z * light.scale.y *
    2 * light.scale.x * light.scale.z;
    
    pdf = solid_angle / cubeArea;
    
    //Check if dividing by 0.f
    pdf = isnan(pdf) ? 0.f : pdf;
    
    return sample_li;
}

float3 sampleSphere(constant Geom&       light,
                    const thread float3&   ref,
                    thread Loki&           rng,
                    thread float3&          wi,
                    thread float&       pdf_li) {
    return float3(0);
}

float3 getEnvironmentColor(texture2d<float, access::sample> environment,
                           device Ray& ray) {
    constexpr sampler textureSampler(coord::normalized,
                                     address::repeat,
                                     min_filter::linear,
                                     mag_filter::linear,
                                     mip_filter::linear);
    float x = ray.direction.x, y = ray.direction.y, z = ray.direction.z;
    float u = atan2(x, z) / (2 * PI) + 0.5f;
    float v = y * 0.5f + 0.5f;
    
    v = 1-v;
    float4 color = environment.sample(textureSampler, float2(u, v));
    return color.xyz;
}


float3 sample_li(constant Geom&         light,
                 const constant Material&   m,
                 const thread float3&     ref,
                 thread Loki&             rng,
                 thread float3&            wi,
                 thread float&         pdf_li) {
    switch (light.type) {
        case CUBE:
            // Get a point on the cube
            sampleCube(light, ref, rng, wi, pdf_li);
            
            // Return the color
            return m.color * m.emittance;
        case SPHERE:
//            return sampleSphere(light, m, ref, rng, wi, pdf_li);
        default:
            return float3(0,0,0);
    }
    
}


/********************************************************
 ********************************************************
 **************** FUNCTION OVERLOADS ********************
 *** Overloaded in order to not compromise efficiency ***
 ********************************************************
 ********************************************************/
// TODO: Avoid doing this

void shadeAndScatter(thread Ray& ray,
                     thread Intersection& isect,
                     thread Material &m,
                     thread Loki& rng,
                     thread float& pdf) {
    switch (m.bsdf) {
        case -1:
            // Light Shade and 'absorb' ray by terminating
            ray.color *= (m.color * m.emittance);
            ray.idx_bounces[2] = 0;
            break;
        case 0:
            SnS_diffuse(ray, isect, m, rng, pdf);
            break;
        case 1:
            SnS_reflect(ray, isect, m, rng, pdf);
            break;
        case 2:
            SnS_refract(ray, isect, m, rng, pdf);
            break;
        default:
            break;
    }
}
