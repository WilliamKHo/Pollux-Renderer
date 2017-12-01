//
//  bsdf_shading_header.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/22/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../Data_Types/PolluxTypes.h"
#include "../Data_Types/Constants.h"
#include "Loki/loki_header.metal"

// TODO: Add comments describing what this file does


using namespace metal;


void SnS_diffuse(device Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread Loki& rng,
                 thread float& pdf);
// for MIS
void SnS_diffuse(thread Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread Loki& rng,
                 thread float& pdf);

void SnS_specular(device Ray& ray,
                  thread Intersection& isect,
                  thread Material &m,
                  thread Loki& rng,
                  thread float& pdf);

void SnS_fresnel(device Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread Loki& rng,
                 thread float& pdf);

void SnS_diffuseDirectLighting(thread Ray& ray,
                               thread Intersection& isect,
                               thread Material &m,
                               thread Loki& rng,
                               thread float& pdf,
                               thread Geom& light);

/**
 * Computes a cosine-weighted random direction in a hemisphere.
 * Used for diffuse lighting.
 *
 * normal:   surface normal to generate direction
 * rng:      An instance of the Loki rng that creates a new random
 *           number at every thread instance
 *
 * RETURNS:  a float3 indicating representing this new random
 *           direction
 *
 */
float3 cosRandomDirection(const  float3 normal,
                          thread Loki& rng);

float3 sampleLight(thread Geom& light,
                   thread Loki& rng);
