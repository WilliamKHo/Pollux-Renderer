//
//  bsdf_shading.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/22/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//


#include "bsdf_shading_header.metal"

using namespace metal;


void SnS_diffuse(device Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread Loki& rng,
                 thread float& pdf) {
    
    const float3 n  = isect.normal;
    const float3 wo = -ray.direction;
    
    // Material's color divided `R` which in this case is InvPi
    float3 f = m.color * InvPi;
    
    //This is lambert factor for light attenuation
    float lambert_factor = fabs(dot(n, wo));
    
    //PDF Calculation
    float dotWo = dot(n, wo);
    float cosTheta = fabs(dotWo) * InvPi;
    pdf = cosTheta;
    
    if (abs(pdf) < ZeroEpsilon) {
        ray.idx_bounces[2] = 0;
        return;
    }
    
    float3 integral = (f * lambert_factor)
                            / pdf;
    ray.color *= integral;
    
    //Scatter the Ray
    ray.origin = isect.point + n*EPSILON;
    ray.direction = cosRandomDirection(n, rng);
    ray.idx_bounces[2]--;
}

void  SnS_reflect(device Ray& ray,
                  thread Intersection& isect,
                  thread Material &m,
                  thread Loki& rng,
                  thread float& pdf) {

    ray.origin = isect.point + isect.normal * EPSILON;
    ray.color *= m.color;
    ray.direction = reflect(ray.direction, isect.normal);
    ray.idx_bounces[2]--;
    pdf = 1;
}

void SnS_refract(device Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread Loki& rng,
                 thread float& pdf) {
    //Figure out which n is incident and which is transmitted
    const bool    entering = isect.outside;
    const float        eta = entering ? 1.0 / m.index_of_refraction : m.index_of_refraction;
    
    float3 refracted = normalize(refract(ray.direction, isect.normal, eta));
    
    if (abs(refracted.x) < ZeroEpsilon &&
        abs(refracted.y) < ZeroEpsilon &&
        abs(refracted.z) < ZeroEpsilon) {
        ray.color = float3(0);
    } else {
        ray.color *= m.color;
    }

    ray.origin = isect.point - isect.normal * EPSILON * 50;
    ray.direction = refracted;
    ray.idx_bounces[2]--;
    pdf = 1.f;
}

void SnS_subsurface(device Ray& ray,
                    thread Intersection& isect,
                    thread Material &m,
                    thread Loki& rng,
                    thread float& pdf) {
    // TODO : Strange visual artifacts with refractive subsurface, for now uses diffusive for
    // entering and exiting the medium
    const bool    entering = isect.outside;
    float3 n = -isect.normal;
    if (entering) {
        //SnS_refract(ray, isect, m, rng, pdf);
        float cosTheta = dot(normalize(-ray.direction), -n);
        float ior = m.index_of_refraction;
        float fresnelCoeff = ((1.0f - ior) / (1.0f + ior)) * ((1.0f - ior) / (1.0f + ior));
        fresnelCoeff = fresnelCoeff + (1.0f - fresnelCoeff) * pow(1.0f - cosTheta, 5.0f);
        SnS_diffuse(ray, isect, m, rng, pdf);
        if (rng.rand() > fresnelCoeff) {
            //diffuse into the medium
            ray.direction += 2*n;
            ray.origin = isect.point + n * 0.1;
        }
        return;
    }
    
    float tFar = length(isect.point - ray.origin);
    float lambda = 1.0f / m.scatteringDistance;
    float t = -log(rng.rand()) / lambda;
    ray.idx_bounces[2]--;
    //Set pdf
    pdf = -lambda * t;
    // Refraction event
    if (t > tFar) {
        //SnS_refract(ray, isect, m, rng, pdf);
        SnS_diffuse(ray, isect, m, rng, pdf);
        ray.direction += 2*n;
        ray.origin = isect.point + n * 0.1;
        ray.color *= exp((log(m.color) / m.absorptionAtDistance) * tFar);
        return;
    }
    ray.origin += ray.direction * t;
    // Scatter event
    // Move ray some distance along it's path
    // Remove energy and adjust direction
    ray.color *= exp((log(m.color) / m.absorptionAtDistance) * t);
    ray.direction = normalize(float3(rng.rand() - 0.5f, rng.rand() - 0.5f, rng.rand() - 0.5f));
    
}

/**************************
 **************************
 ***** HELPER METHODS *****
 **************************
 **************************/

float3 cosRandomDirection(const float3 normal,
                          thread Loki& rng) {
    float up = sqrt(rng.rand()); // cos(theta)
    float over = sqrt(1 - up * up); // sin(theta)
    float around = rng.rand() * TWO_PI;
    
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


/********************************************************
 ********************************************************
 **************** FUNCTION OVERLOADS ********************
 *** Overloaded in order to not compromise efficiency ***
 ********************************************************
 ********************************************************/

void SnS_diffuse(thread Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread Loki& rng,
                 thread float& pdf) {
    
    const float3 n  = isect.normal;
    const float3 wo = -ray.direction;
    
    // Material's color divided `R` which in this case is InvPi
    float3 f = m.color * InvPi;
    
    //This is lambert factor for light attenuation
    float lambert_factor = fabs(dot(n, wo));
    
    //PDF Calculation
    float dotWo = dot(n, wo);
    float cosTheta = fabs(dotWo) * InvPi;
    pdf = cosTheta;
    
    if (abs(pdf) < ZeroEpsilon) {
        ray.idx_bounces[2] = 0;
        return;
    }
    
    float3 integral = (f * lambert_factor)
    / pdf;
    ray.color *= integral;
    
    //Scatter the Ray
    ray.origin = isect.point + n*EPSILON;
    ray.direction = cosRandomDirection(n, rng);
    ray.idx_bounces[2]--;
}

void  SnS_reflect(thread Ray& ray,
                  thread Intersection& isect,
                  thread Material &m,
                  thread Loki& rng,
                  thread float& pdf) {
    
    ray.origin = isect.point + isect.normal * EPSILON;
    ray.color *= m.color;
    ray.direction = reflect(ray.direction, isect.normal);
    ray.idx_bounces[2]--;
    pdf = 1;
}

void SnS_refract(thread Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread Loki& rng,
                 thread float& pdf) {
    //Figure out which n is incident and which is transmitted
    const bool    entering = isect.outside;
    const float        eta = entering ? m.index_of_refraction : 1.0 / m.index_of_refraction;
    
    float3 refracted = refract(-ray.direction, isect.normal, eta);
    
    if (abs(refracted.x) < ZeroEpsilon &&
        abs(refracted.y) < ZeroEpsilon &&
        abs(refracted.z) < ZeroEpsilon) {
        ray.color = float3(0);
    } else {
        ray.color *= m.color;
    }
    
    ray.origin = isect.point;
    ray.direction = refracted;
    ray.idx_bounces[2]--;
    pdf = 1.f;
}

void SnS_subsurface(thread Ray& ray,
                    thread Intersection& isect,
                    thread Material &m,
                    thread Loki& rng,
                    thread float& pdf) {
    // TODO : Strange visual artifacts with refractive subsurface, for now uses diffusive for
    // entering and exiting the medium
    const bool    entering = isect.outside;
    float3 n = -isect.normal;
    if (entering) {
        //SnS_refract(ray, isect, m, rng, pdf);
        float cosTheta = dot(normalize(-ray.direction), -n);
        float ior = m.index_of_refraction;
        float fresnelCoeff = ((1.0f - ior) / (1.0f + ior)) * ((1.0f - ior) / (1.0f + ior));
        fresnelCoeff = fresnelCoeff + (1.0f - fresnelCoeff) * pow(1.0f - cosTheta, 5.0f);
        SnS_diffuse(ray, isect, m, rng, pdf);
        if (rng.rand() > fresnelCoeff) {
            //diffuse into the medium
            ray.direction += 2*n;
            ray.origin = isect.point + n * 0.1;
        }
        return;
    }
    
    float tFar = length(isect.point - ray.origin);
    float lambda = 1.0f / m.scatteringDistance;
    float t = -log(rng.rand()) / lambda;
    ray.idx_bounces[2]--;
    //Set pdf
    pdf = -lambda * t;
    // Refraction event
    if (t > tFar) {
        //SnS_refract(ray, isect, m, rng, pdf);
        SnS_diffuse(ray, isect, m, rng, pdf);
        ray.direction += 2*n;
        ray.origin = isect.point + n * 0.1;
        ray.color *= exp((log(m.color) / m.absorptionAtDistance) * tFar);
        return;
    }
    ray.origin += ray.direction * t;
    // Scatter event
    // Move ray some distance along it's path
    // Remove energy and adjust direction
    ray.color *= exp((log(m.color) / m.absorptionAtDistance) * t);
    ray.direction = normalize(float3(rng.rand() - 0.5f, rng.rand() - 0.5f, rng.rand() - 0.5f));
    
}


