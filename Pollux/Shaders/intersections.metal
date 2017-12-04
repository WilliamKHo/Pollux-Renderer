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
                                device Ray    &r,
                                thread float3 &intersectionPoint,
                                thread float3 &normal,
                                thread bool   &outside) {
    float radius = .5f;
    
    thread Ray rt;
    rt.origin = float3(sphere->inverseTransform * float4(r.origin, 1.0f));
    rt.direction = normalize(float3(sphere->inverseTransform * float4(r.direction, 0.0f)));
    
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

float computeCubeIntersection(device Geom   *box,
                              device Ray    &r,
                              thread float3 &intersectionPoint,
                              thread float3 &normal,
                              thread bool   &outside) {
    thread Ray rt;
    rt.origin    =           float3(box->inverseTransform * float4(r.origin, 1.0f));
    rt.direction = normalize(float3(box->inverseTransform * float4(r.direction, 0.0f)));
    
    float tmin = -1e38f;
    float tmax = 1e38f;
    float3 tmin_n;
    float3 tmax_n;
    for (int dim = 0; dim < 3; ++dim) {
        float dir_dim = rt.direction[dim];
        /*if (glm::abs(qddim) > 0.00001f)*/ {
            float t1 = (-0.5f - rt.origin[dim]) / dir_dim;
            float t2 = (+0.5f - rt.origin[dim]) / dir_dim;
            float ta = min(t1, t2);
            float tb = max(t1, t2);
            float3 n;
            n[dim] = t2 < t1 ? +1 : -1;
            if (ta > 0 && ta > tmin) {
                tmin = ta;
                tmin_n = n;
            }
            if (tb < tmax) {
                tmax = tb;
                tmax_n = n;
            }
        }
    }
    
    if (tmax >= tmin && tmax > 0) {
        outside = true;
        if (tmin <= 0) {
            tmin = tmax;
            tmin_n = tmax_n;
            outside = false;
        }
        intersectionPoint =  float3(box->transform * float4(getPointOnRay(&rt, tmin), 1.0f));
        normal = normalize(float3(box->invTranspose * float4(tmin_n, 0.0f)));
        
        return length(r.origin - intersectionPoint);
    }
    return -1;
}
