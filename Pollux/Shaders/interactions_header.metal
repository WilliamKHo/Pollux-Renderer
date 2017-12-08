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
#include "bsdf_shading_header.metal"

// TODO: Add more Documentation here

using namespace metal;

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
 * rng:         An instance of the Loki rng that creates a new random
 *              number at every thread instance
 * pdf:         The probability that the ray would be scattered in this newly
 *              sampled direction
 */
void shadeAndScatter(device Ray& ray,
                     thread Intersection& isect,
                     thread Material &m,
                     thread Loki& rng,
                     thread float& pdf);

/**
 * Sample a point on a cube.
 * - Used in MIS for picking a random point on a Cube Lights
 */
float3 sampleCube(constant Geom&         light,
                  const thread float3&     ref,
                  thread Loki&             rng,
                  thread float3&            wi,
                  thread float&         pdf_li);

/**
 * Sample a point on a sphere.
 * - Used in MIS for picking a random point on a Spherical Lights
 */
float3 sampleSphere(constant Geom&       light,
                    const thread float3&   ref,
                    thread Loki&           rng,
                    thread float3&          wi,
                    thread float&       pdf_li);


/**
 * Sample a random point `shape_sample` on a scene light.
 *
 * light:       The scene light that we're sampling
 * m:           Intersected object's material
 * ref:         Ray's origin
 * rng:         An instance of the Loki rng that creates a new random
 *              number at every thread instance
 * wi:          incoming ray direction, calculated in the function
 * pdf_li:      The probability that we pick `shape_sample`,
 *              calculated in the function.
 *
 * RETURNS:     the color of the light at `shape_sample`
 */
float3 sample_li(constant Geom&         light,
                 const constant Material&   m,
                 const thread float3&     ref,
                 thread Loki&             rng,
                 thread float3&            wi,
                 thread float&         pdf_li);



/********************************************************
 ********************************************************
 **************** FUNCTION OVERLOADS ********************
 *** Overloaded in order to not compromise efficiency ***
 ********************************************************
 ********************************************************/
void shadeAndScatter(thread Ray& ray,
                     thread Intersection& isect,
                     thread Material &m,
                     thread Loki& rng,
                     thread float& pdf);

float3 getEnvironmentColor(texture2d<float, access::sample> environment,
                           constant float3& emittance,
                           device Ray& ray);

