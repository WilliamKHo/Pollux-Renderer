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
                             const constant  float*       kdtrees,
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
        } else if (geom.type == PLANE) {
            t = computePlaneIntersection(&geom, ray, tmp_intersect, tmp_normal, outside);
        } else if (geom.type == MESH) {
            t = computeMeshIntersection(&geom, kdtrees, ray, tmp_intersect, tmp_normal, outside);
        }
        
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
        intersection.t          = t_min;
        intersection.materialId = geoms[hit_geom_index].materialid;
        intersection.normal     = normal;
        intersection.point      = intersect_point;
        intersection.outside    = outside;
        
        // Get UV Coordinates
        getUVCoordinates(intersection, geoms[hit_geom_index]);
        
        // Sets Shading Normal
        computeTBN(intersection, geoms[hit_geom_index]);
    }
    
    return intersection;
}

float computeSphereIntersection(constant    Geom    *sphere,
                                const thread Ray    &r,
                                thread   float3 &intersectionPoint,
                                thread   float3 &normal,
                                thread   bool   &outside) {
    const float radius = .5f;
    
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

float computePlaneIntersection(constant Geom   *plane,
                              const thread Ray    &r,
                              thread   float3 &intersectionPoint,
                              thread   float3 &normal,
                              thread   bool   &outside) {
    Ray r_loc;
    r_loc.origin = float3(plane->inverseTransform * float4(r.origin, 1.0f));
    r_loc.direction = float3(plane->inverseTransform * float4(r.direction, 0.0f));
    
    const float t = dot(float3(0, 0, 1), (float3(0.5f, 0.5f, 0) - r_loc.origin)) / dot(float3(0, 0, 1), r_loc.direction);
    const float3 p = float3(t * r_loc.direction + r_loc.origin);
    
    if (t > 0 && p.x >= -0.5f && p.x <= 0.5f && p.y >= -0.5f && p.y <= 0.5f) {
        intersectionPoint = float3(plane->transform * float4(p,1));
        normal = normalize(float3(plane->invTranspose * float4(0, 0, 1, 0)));
        return t;
    }
    
    return -1;
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

// Helper Method for mesh intersection test
bool aabbIntersectionTest(const thread Ray& r,
                          thread float3 minVec,
                          thread float3 maxVec,
                          thread float & tmin,
                          thread float & tmax) {
    
    tmin = -1e38f;
    tmax = 1e38f;
    
    for (int xyz = 0; xyz < 3; ++xyz) {
        float qdxyz = r.direction[xyz];
        /*if (glm::abs(qdxyz) > 0.00001f)*/ {
            float t1 = (minVec[xyz] - r.origin[xyz]) / qdxyz;
            float t2 = (maxVec[xyz] - r.origin[xyz]) / qdxyz;
            float ta = min(t1, t2);
            float tb = max(t1, t2);
            if (ta > 0 && ta > tmin)
                tmin = ta;
            if (tb < tmax)
                tmax = tb;
        }
    }
    
    if (tmax >= tmin && tmax > 0)
    {
        if (tmin <= 0)
            tmin = 0.f;
        
        return true;
    }
    
    return false;
}

float computeMeshIntersection(constant Geom   *mesh,
                              constant float  *kdtrees,
                              const thread Ray    &ray,
                              thread   float3 &intersectionPoint,
                              thread   float3 &normal,
                              thread   bool   &outside) {
    outside = true;
    float minDistance = -1000000.f;
    float maxDistance = 1000000.f;

    Ray r = ray;
    r.origin = float3(mesh->inverseTransform * float4(r.origin, 1.0f));
    r.direction = normalize(float3(mesh->inverseTransform * float4(r.direction, 0.0f)));

    // If we dont hit the AABB, return!
    if (!aabbIntersectionTest(r, mesh->meshData.minAABB, mesh->meshData.maxAABB, minDistance, maxDistance)) {
        return -1.f;
    }
    

    float3 invRayDir = float3(1.f / r.direction.x, 1.f / r.direction.y, 1.f / r.direction.z);
    StackData stack[64] = { };
    int stackTop = 0;

    bool hit = false;
    int currentNode = 0;

    float intersectionDistance = 1000000.f;
    constant float * compactNodes = (constant float*) (kdtrees + mesh->meshData.meshIndex);

    float3 localNormal;

    // The stack approach is very similar to pbrtv3
    while (currentNode != -1 && stackTop < 64)
    {
        // If on a previous loop there was an intersection and is closer
        // than the current node min distance, don't even start checking intersections
        if (intersectionDistance < minDistance)
            break;

        constant float* node = (constant float*)(compactNodes + currentNode);
        int leftNode   = *(node + 0);
        int rightNode  = *(node + 1);
        float split    = *(node + 2);
        int axis       = *(node + 3);

        // Leaf
        if (leftNode == -1 && rightNode == -1)
        {
            int primitiveCount = *(node + 4);
            constant CompactTriangle* flatElements = (constant CompactTriangle*)(compactNodes + currentNode + 5);

            // Check intersection with all primitives inside this node
            for (int i = 0; i < primitiveCount; i++)
            {
                constant CompactTriangle& tri = flatElements[i];

                float3 e1(tri.e1x, tri.e1y, tri.e1z);
                float3 e2(tri.e2x, tri.e2y, tri.e2z);
                float3 p1(tri.p1x, tri.p1y, tri.p1z);

                float3 t = r.origin - p1;
                float3 p = cross(r.direction, e2);
                float3 q = cross(t, e1);

                float multiplier  = 1.f / dot(p, e1);
                float rayT = multiplier * dot(q, e2);
                float u = multiplier    * dot(p, t);
                float v = multiplier    * dot(q, r.direction);

                if (rayT < intersectionDistance && rayT >= 0.f && u >= 0.f && v >= 0.f && u + v <= 1.f)
                {
                    intersectionDistance = rayT;
                    float3 n1(tri.n1x, tri.n1y, tri.n1z);
                    float3 n2(tri.n2x, tri.n2y, tri.n2z);
                    float3 n3(tri.n3x, tri.n3y, tri.n3z);
                    localNormal = normalize(n1 + n2 + n3);
                    hit = true;
                }
            }

            if (stackTop > 0)
            {
                stackTop--;
                currentNode = stack[stackTop].nodeOffset;
                minDistance = stack[stackTop].minDistance;
                maxDistance = stack[stackTop].maxDistance;
            }
            else break; // There's no other object in the stack, we finished iterating!
        }
        else
        {
            float t = (split - r.origin[axis]) * invRayDir[axis];
            int nearNode = leftNode;
            int farNode  = rightNode;

            if (r.origin[axis] >= split && !(r.origin[axis] == split && r.direction[axis] < 0))
            {
                nearNode = rightNode;
                farNode = leftNode;
            }

            if (t > maxDistance || t <= 0)
                currentNode = nearNode;
            else if (t < minDistance)
                currentNode = farNode;
            else
            {
                stack[stackTop].nodeOffset = farNode;
                stack[stackTop].minDistance = t;
                stack[stackTop].maxDistance = maxDistance;
                stackTop++; // Increment the stack
                currentNode = nearNode;
                maxDistance = t;
            }
        }
    }

    if (hit)
    {
        float3 localP = r.origin + r.direction * intersectionDistance;
        intersectionPoint = float3(mesh->transform * float4(localP, 1.f));
        normal = normalize(float3(mesh->invTranspose * float4(localNormal, 0.f)));

        // Make sure triangles are double sided
        if (dot(r.direction, normal) > 0.f)
            normal *= -1.f;

        return distance(ray.origin, intersectionPoint);
    }
    
    return -1.f;
}
