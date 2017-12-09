//
//  shapes_header.metal
//  Pollux-macOS
//
//  Created by Youssef Victor on 12/8/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../Data_Types/PolluxTypes.h"
#include "../Data_Types/Constants.h"
#include "Loki/loki_header.metal"
using namespace metal;


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
 * Computes the area of a given shape.
 * - Determines type and then computes
 */
float  shapeSurfaceArea(constant Geom&    shape);
