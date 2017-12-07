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
float3 getPointOnRay(const thread Ray* r,
                     const thread float& t) {
    return r->origin + (t - .0001f) * normalize(r->direction);
}

Intersection getIntersection(const thread       Ray          &ray,
                             const constant   Geom*         geoms,
                                   constant   uint&   geom_count) {
    // The Intersection to be returned
    Intersection intersection;
    
    float t;
    float3 intersect_point;
    float3 normal;
    float t_min = FLT_MAX;
    int hit_geom_index = -1;
    bool outside = true;
    
    float3 tmp_intersect;
    float3 tmp_normal;
    
    // naive parse through global geoms
    for (uint i = 0; i < geom_count; i++)
    {
        constant Geom& geom = geoms[i];
        
        if (geom.type == CUBE)
        {
            t = computeCubeIntersection(&geom, ray, tmp_intersect, tmp_normal, outside);
        }
        else if (geom.type == SPHERE)
        {
            t = computeSphereIntersection(&geom, ray, tmp_intersect, tmp_normal, outside);
        }
        // TODO: add more intersection tests here... triangle? metaball? CSG?
        
        // Compute the minimum t from the intersection tests to determine what
        // scene geometry object was hit first.
        if (t > 0.0f && t_min > t)
        {
            t_min = t;
            hit_geom_index = i;
            intersect_point = tmp_intersect;
            normal = tmp_normal;
        }
    }
    
    if (hit_geom_index == -1)
    {
        // The ray doesn't hit something (index == -1)
        intersection.t = -1.0f;
    }
    else
    {
        //The ray hits something
        intersection.t = t_min;
        intersection.materialId = geoms[hit_geom_index].materialid;
        intersection.normal = normal;
        intersection.point = intersect_point;
        intersection.outside = outside;
    }
    
    return intersection;
}

float computeSphereIntersection(constant    Geom    *sphere,
                                const thread Ray    &r,
                                thread   float3 &intersectionPoint,
                                thread   float3 &normal,
                                thread   bool   &outside) {
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

float computeCubeIntersection(constant Geom   *box,
                              const thread Ray    &r,
                              thread   float3 &intersectionPoint,
                              thread   float3 &normal,
                              thread   bool   &outside) {
    thread Ray rt;
    rt.origin    =           float3(box->inverseTransform * float4(r.origin, 1.0f));
    rt.direction = normalize(float3(box->inverseTransform * float4(r.direction, 0.0f)));
    
    float tmin = -1e38f;
    float tmax = 1e38f;
    float3 tmin_n;
    float3 tmax_n;
    for (int dim = 0; dim < 3; ++dim) {
        float dir_dim = rt.direction[dim];
//        /*if (glm::abs(qddim) > 0.00001f)*/ {
            float t1 = (-0.5f - rt.origin[dim]) / dir_dim;
            float t2 = (+0.5f - rt.origin[dim]) / dir_dim;
            float ta = min(t1, t2);
            float tb = max(t1, t2);
            float3 n = float3(0);
            n[dim] = t2 < t1 ? +1 : -1;
            if (ta > 0 && ta > tmin) {
                tmin = ta;
                tmin_n = n;
            }
            if (tb < tmax) {
                tmax = tb;
                tmax_n = n;
            }
//        }
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
