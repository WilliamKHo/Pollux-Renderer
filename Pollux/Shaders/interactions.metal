//
//  interactions.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/22/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include "interactions_header.metal"
#include "mis_helper_header.metal"

using namespace metal;

void shadeAndScatter(device Ray& ray,
                     thread Intersection& isect,
                     thread Material &m,
                     thread Loki& rng,
                     thread float& pdf) {
    thread Ray r = ray;
    shadeAndScatter(r, isect, m, rng, pdf);
    ray = r;
}


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
            break;
        case 2:
            break;
        default:
            break;
    }
}

void scatterRay(device Ray& ray,
                thread Intersection& isect,
                thread Material &m,
                thread Loki& rng,
                thread float& pdf) {
    thread Ray r = ray;
    scatterRay(r, isect, m, rng, pdf);
    ray = r;
}

void scatterRay(thread Ray& ray,
                thread Intersection& isect,
                thread Material &m,
                thread Loki& rng,
                thread float& pdf) {
    switch (m.bsdf) {
        case -1:
            break;
        case 0:
            //PDF Calculation
            pdf = fabs(dot(isect.normal, -ray.direction)) * InvPi;
            if (abs(pdf) < ZeroEpsilon) {
                ray.idx_bounces[2] = 0;
                break;
            }
            ray.origin = isect.point + isect.normal*EPSILON;
            ray.direction = cosRandomDirection(isect.normal, rng);
            ray.idx_bounces[2]--;
            break;
        case 1:
            break;
        case 2:
            break;
        default:
            break;
    }
}

float3 sample_li(device Geom& light,
                 device Material& m,
                 thread float3& ref,
                 thread Loki& rng,
                 thread float3& wi,
                 thread float& pdf_li) {
    return sampleCube(light, m, ref, rng, wi, pdf_li);
}
