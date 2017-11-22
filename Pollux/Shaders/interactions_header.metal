//
//  interactions_header.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/22/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../Data_Types/PolluxTypes.h"
#include "../Data_Types/Constants.h"
#include "bsdf_interactions_header.metal"

using namespace metal;

/**
 * Computes a cosine-weighted random direction in a hemisphere.
 * Used for diffuse lighting.
 *
 * normal:   surface normal to generate direction
 * random:   the last number seeded from the PRNG, Loki.
 *           Also used as a seed for future calls.
 *
 * RETURNS:  a float3 indicating representing this new random
 *           direction
 *
 */
float3 cosRandomDirection(const  float3 normal,
                          thread float& random);

/**
 * Scatter a ray with some probabilities according to the material properties.
 * For example, a diffuse surface scatters in a cosine-weighted hemisphere.
 * A perfect specular surface scatters in the reflected ray direction.
 * In order to apply multiple effects to one surface, probabilistically choose
 * between them.
 *
 * This scatters rays according to their Bidirectional Scattering Distribution
 * Function that is a property of whichever material you intersect.
 *
 * ray:         The ray to be scattered and shaded
 * isect:       Ray-object intersection point. Used to scatter Ray further
 * m:           Intersected object's material
 * random:      random number
 * pdf:         The probability that the ray would be scattered in this newly
 *              sampled direction
 */
void shadeAndScatter(device Ray& ray,
                     thread Intersection& isect,
                     thread Material &m,
                     thread float& random,
                     thread float& pdf);
/**
 * Sample a random point `shape_sample` on a scene light.
 *
 * light:       The scene light that we're sampling
 * m:           Intersected object's material
 * ref:         Ray's origin
 * random:      random number used for seed for Loki
 * wi:          incoming ray direction, calculated in the function
 * pdf_li:      The probability that we pick `shape_sample`,
 *              calculated in the function.
 *
 * RETURNS:     the color of the light at `shape_sample`
 */
float3 sample_li(device Geom& light,
                 device Material& m,
                 constant float3& ref,
                 thread float& random,
                 thread float3 *wi,
                 thread float* pdf_li);

