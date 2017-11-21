//
//  intersections_header.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/21/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "PolluxTypes.h"

using namespace metal;

/**
 * Compute a point at parameter value `t` on ray `r`.
 * Falls slightly short so that it doesn't intersect the object it's hitting.
 */
float3 getPointOnRay(thread Ray* r,
                     thread float& t);

/**
 * Compute the intersection of a ray `r` with a sphere geometry
 * Falls slightly short so that it doesn't intersect the object it's hitting.
 */
float computeSphereIntersection(device Geom   *sphere,
                                thread Ray    &r,
                                thread float3 &intersectionPoint,
                                thread float3 &normal,
                                thread bool   &outside);
