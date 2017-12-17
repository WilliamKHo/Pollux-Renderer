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


/**
 * This file contains the heart of the shading for Pollux.
 * Each BSDF has it's own shading function which handles all
 * shading and scattering (SnS) logic. The code base Pollux
 * is based off of uses this, and we never thought of fixing things.
 *
 * The better way would be to separate shading and scattering logic
 * as you never know when you might need either. Also, more importantly
 * The code structure described in Physically Based Rendering Techniques
 * by Matt Phar, Wenzel Jacob, and Greg Humphreys is a lot more robust
 * A future potential improvement is to adapt that method. For now,
 * this will have to do.
 *
 * Nevertheless, here are the function parameter definitions:
 *
 * - ray:       the incoming ray to scatter and shade
 *
 * - isect:     the ray's intersection point with the object
 *
 * - m:         the intersected object's material properties
 *
 * - rng:       a random number generator passed in by reference
 *              to support multiple calls to .rand()
 *
 * - pdf:       the pdf of the ray after it has been scattered
 *              this is used to balance ray contribution and is
 *              passed in by reference as well as it's filled in
 *              based on the scattering
 */


using namespace metal;


/***
 ***   Perfectly Diffuse Material.
 ***
 ***   - diffuse materials scatter light equally in all directions
 ***     a cosine weighted sampling method is used here to ignore
 ***     rays that have a very low contribution to the overall scene.
 ***     (see the cosRandomDirection method for how.)
 ***/
void SnS_diffuse(thread Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread Loki& rng,
                 thread float& pdf);

/***
 ***   Perfectly Specular Material.
 ***
 ***   - specular materials reflect rays across the normal exactly
 ***     there is almost no such thing as a perfectly specular material
 ***     in real life, but this is not real life though.
 ***
 ***   - pdf is set to 1 here as there is only one possibility of
 ***     reflected ray directions
 ***/
void SnS_reflect(thread Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread Loki& rng,
                 thread float& pdf);

/***
 ***   Perfectly Transmissive Material.
 ***
 ***   - specular transmissive rays reflect across the normal exactly
 ***     there is almost no such thing as a perfectly transmissive material
 ***     in real life, but this is not real life though.
 ***
 ***   - pdf is set to 1 here as there is only one possibility of
 ***     refracted ray direction.
 ***/
void SnS_refract(thread Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread Loki& rng,
                 thread float& pdf);

/***
 ***   A microfacet transmissive material that is based on the torrance-sparrow
 ***   microfacet model.
 ***
 ***   - this is still a work in progress, so everything is commented out now.
 ***     I'm running into troubles getting the sin/cos phi in world space. Need
 ***     to figure that one out.
 ***/
void SnS_microfacetBTDF(thread Ray& ray,
                        thread Intersection& isect,
                        thread Material &m,
                        thread Loki& rng,
                        thread float& pdf);

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
