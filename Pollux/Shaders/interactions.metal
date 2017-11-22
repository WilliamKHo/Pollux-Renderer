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
                     thread float& random,
                     thread float& pdf) {
    switch (m.bsdf) {
        case -1:
            // Light Shade and 'absorb' ray by terminating
            ray.color *= (m.color * m.emittance);
            ray.idx_bounces.x = 0;
            break;
        case 0:
            SnS_diffuse(ray, isect, m, random, pdf);
            break;
        case 1:
            break;
        case 2:
            break;
        default:
            break;
    }
}

float3 sample_li(constant Geom& light,
                 constant Material& m,
                 constant float3& ref,
                 thread float& random,
                 thread float3 *wi,
                 thread float* pdf_li) {
    return float3(0);
}


