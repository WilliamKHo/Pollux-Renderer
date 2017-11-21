//
//  intersections.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/21/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include "intersections_header.metal"

using namespace metal;

/**
 * Compute a point at parameter value `t` on ray `r`.
 * Falls slightly short so that it doesn't intersect the object it's hitting.
 */
float3 getPointOnRay(thread Ray* r,
                     thread float& t) {
    return r->origin + (t - .0001f) * normalize(r->direction);
}

float computeSphereIntersection(device Geom   *sphere,
                                thread Ray    &r,
                                thread float3 &intersectionPoint,
                                thread float3 &normal,
                                thread bool   &outside) {
    float radius = .5f;
    
    float3 ray_o = float3(sphere->inverseTransform * float4(r.origin, 1.0f));
    float3 ray_d = normalize(float3(sphere->inverseTransform * float4(r.direction, 0.0f)));
    
    thread Ray rt;
    rt.origin = ray_o;
    rt.direction = ray_d;
    
    float vDotDirection = dot(rt.origin, rt.direction);
    float radicand = vDotDirection * vDotDirection - (dot(rt.origin, rt.origin) - pow(radius, 2));
    if (radicand < 0) {
        return -1.f;
    }
    
    float squareRoot = sqrt(radicand);
    float firstTerm = -vDotDirection;
    float t1 = firstTerm + squareRoot;
    float t2 = firstTerm - squareRoot;
    
    thread float t = 0;
    if (t1 < 0 && t2 < 0) {
        return -1;
    } else if (t1 > 0 && t2 > 0) {
        t = min(t1, t2);
        outside = true;
    } else {
        t = max(t1, t2);
        outside = false;
    }
    
    float3 objspaceIntersection = getPointOnRay(&rt, t);
    
    intersectionPoint = float3(sphere->transform * float4(objspaceIntersection, 1.f));
    normal = normalize(float3(sphere->invTranspose * float4(objspaceIntersection, 0.f)));
    if (!outside) {
        normal = -normal;
    }
    
    return length(r.origin - intersectionPoint);
}
