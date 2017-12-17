//
//  PolluxTypes.h
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/8/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#ifndef PolluxTypes_h
#define PolluxTypes_h

#import "simd/simd.h"
#include "MicrofacetDistributions.h"

#define MAX_FILENAME_LENGTH 50

#define DEPTH 8.f
#define FOV   45.f
#define MAX_GEOMS 10


enum GeomType {
    SPHERE,
    CUBE,
    PLANE,
    MESH
};

enum PipelineStage {
    GENERATE_RAYS,
    COMPUTE_INTERSECTIONS,
    SHADE,
    COMPACT_RAYS,
    FINAL_GATHER,
};

typedef struct {
    int meshIndex;
    vector_float3 minAABB;
    vector_float3 maxAABB;
} MeshDescriptor;

typedef struct
{
    // Data
    float e1x;
    float e1y;
    float e1z;
    
    float e2x;
    float e2y;
    float e2z;
    
    float p1x;
    float p1y;
    float p1z;
    
    // Normals
    float n1x;
    float n1y;
    float n1z;
    
    float n2x;
    float n2y;
    float n2z;
    
    float n3x;
    float n3y;
    float n3z;
} CompactTriangle;

typedef struct {
    enum GeomType type;
    int materialid;
    vector_float3 translation;
    vector_float3 rotation;
    vector_float3 scale;
    matrix_float4x4 transform;
    matrix_float4x4 inverseTransform;
    matrix_float4x4 invTranspose;
    
    MeshDescriptor meshData;
} Geom;

typedef struct
{
    int nodeOffset;
    float minDistance;
    float maxDistance;
} StackData;

typedef struct {
    
    vector_float3 bounds_min;
    vector_float3 bounds_max;
    vector_float3 bounds_center;
} AABB;

typedef struct {
    vector_float3 color;
    float         specular_exponent;
    
    vector_float3 specular_color;
    float hasReflective;
    
    vector_float3 emittance;
    float hasRefractive;
    
    enum MicrofacetDistribution distribution;
    float index_of_refraction;
    short bsdf;
} Material;

typedef struct {
    // Ray Info
    vector_float3 origin;
    vector_float3 direction;
    vector_float3 color;
    vector_float3 throughput;
    
    // Ray's Pixel Index x, y, and Remaining Bounces
    vector_uint3 idx_bounces;
    unsigned int specularBounce;
} Ray;

typedef struct {
    // Stores  WIDTH, HEIGHT, FOV, DEPTH (4 floats)
    vector_float4 data;
    
    // Camera's Position (duh)
    vector_float3 pos;
    // Stores the target the camera is looking at
    vector_float3 lookAt;
    // Direction Camera is looking in
    vector_float3 view;
    // The camera's right vector
    vector_float3 right;
    // The camera's up vector
    vector_float3 up;
    // Lens Information (lensRadius, focalDistance) for DOF
    vector_float2 lensData;
} Camera;

// Use with a corresponding PathSegment to do:
// 1) color contribution computation
// 2) BSDF evaluation: generate a new ray
typedef struct {
    // Surface Normal At the Point of interseciton. No Transformations are applied to it.
    vector_float3 normal;
    float t;
    
    vector_float3 point;
    int materialId;
    
    int outside;
    float2 uv;               // The UV coordinates computed at the intersection
    float3 tangent, bitangent;
    
    Geometry const * objectHit;     // The object that the ray intersected, or nullptr if the ray hit nothing.
} Intersection;

#endif /* PolluxTypes_h */
