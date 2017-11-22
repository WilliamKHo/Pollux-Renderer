//
//  bsdf_interactions.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/22/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//


#include "bsdf_interactions_header.metal"

using namespace metal;


void SnS_diffuse(device Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread float& random,
                 thread float& pdf) {
    const float3 n  = isect.normal;
    const float3 wo = -ray.direction;
    

    float3 accum_color = m.color * InvPi;
    
    //This is lamberFactor. See Line 23 of NaiveIntegrator.cpp in my CPU Pathtracer
    float lambert_factor = fabs(dot(n, wo));
    
    //PDF Calculation
    float dotWo = dot(n, wo);
    float cosTheta = fabs(dotWo) * InvPi;
    pdf = cosTheta;
    
    if (abs(pdf) < ZeroEpsilon) {
        ray.idx_bounces.x = 0;
        return;
    }
    
    float3 integral = (accum_color * lambert_factor)
                                    / pdf;
    ray.color *= integral;
    
    //Scatter the Ray
    ray.origin = isect.point + n*EPSILON;
    ray.direction = cosRandomDirection(n, random);
    ray.idx_bounces.x--;
}

void SnS_specular(device Ray& ray,
                  thread Intersection& isect,
                  thread Material &m,
                  thread float& random,
                  thread float& pdf) {
    // TODO: Add Specular BSDF Interaction
}

void SnS_fresnel(device Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread float& random,
                 thread float& pdf) {
    // TODO: Add Fresnel BSDF Interaction
}

/**************************
 **************************
 ***** HELPER METHODS *****
 **************************
 **************************/

float3 cosRandomDirection(const float3 normal,
                          thread float&  random) {
    float up = sqrt(random); // cos(theta)
    float over = sqrt(1 - up * up); // sin(theta)
    random = Loki::rng(random);
    float around = random * TWO_PI;
    
    // Find a direction that is not the normal based off of whether or not the
    // normal's components are all equal to sqrt(1/3) or whether or not at
    // least one component is less than sqrt(1/3). Taken from CUDA Pathtracer.
    // Originally learned from Peter Kutz.
    
    float3 directionNotNormal;
    if (abs(normal.x) < SQRT_OF_ONE_THIRD) {
        directionNotNormal = float3(1, 0, 0);
    }
    else if (abs(normal.y) < SQRT_OF_ONE_THIRD) {
        directionNotNormal = float3(0, 1, 0);
    }
    else {
        directionNotNormal = float3(0, 0, 1);
    }
    
    // Use not-normal direction to generate two perpendicular directions
    float3 perpendicularDirection1 =
    normalize(cross(normal, directionNotNormal));
    float3 perpendicularDirection2 =
    normalize(cross(normal, perpendicularDirection1));
    
    return up * normal
    + cos(around) * over * perpendicularDirection1
    + sin(around) * over * perpendicularDirection2;
}
