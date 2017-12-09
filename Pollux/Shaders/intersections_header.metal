//
//  intersections_header.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/21/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../Data_Types/PolluxTypes.h"

using namespace metal;

/**
 * Compute a point at parameter value `t` on ray `r`.
 * Falls slightly short so that it doesn't intersect the object it's hitting.
 */
float3 getPointOnRay(const thread Ray*   r,
                     const thread float& t);

/**
 * Check for intersections in the scene
 */
// TODO: KD-Tree
Intersection getIntersection(const thread      Ray&           ray,
                             const constant   Geom*         geoms,
                                   constant   uint&   geoms_count);

/**
 * Compute the intersection of a ray `r` with a sphere geometry
 * Falls slightly short so that it doesn't intersect the object it's hitting.
 */
float computeSphereIntersection(constant Geom      *sphere,
                                const    thread Ray     &r,
                                thread   float3 &intersectionPoint,
                                thread   float3 &normal,
                                thread   bool   &outside);

/**
 * Compute the intersection of a ray `r` with a plane geometry
 * Falls slightly short so that it doesn't intersect the object it's hitting.
 */
float computePlaneIntersection(constant Geom        *plane,
                               const    thread Ray     &r,
                               thread   float3 &intersectionPoint,
                               thread   float3 &normal,
                               thread   bool   &outside);

/**
 * Compute the intersection of a ray `r` with a cube geometry
 * Falls slightly short so that it doesn't intersect the object it's hitting.
 */
float computeCubeIntersection(constant Geom        *cube,
                              const    thread Ray     &r,
                              thread   float3 &intersectionPoint,
                              thread   float3 &normal,
                              thread   bool   &outside);
