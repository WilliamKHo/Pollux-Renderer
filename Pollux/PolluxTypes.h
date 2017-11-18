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

#define DEPTH 8.f
#define FOV   45.f


enum GeomType {
    SPHERE,
    CUBE,
    // TODO: - MESH?
};

enum PipelineStage {
    GENERATE_RAYS,
    COMPUTE_INTERSECTIONS,
    SHADE,
    FINAL_GATHER,
};

typedef struct {
    enum GeomType type;
    int materialid;
    vector_float3 translation;
    vector_float3 rotation;
    vector_float3 scale;
    matrix_float4x4 transform;
    matrix_float4x4 inverseTransform;
    matrix_float4x4 invTranspose;
} Geom;

//typedef struct {
//    vector_float3 color;
//
//    float         specular_exponent;
//    vector_float3 specular_color;
//
//    float hasReflective;
//    float hasRefractive;
//    float indexOfRefraction;
//    float emittance;
//} Material;

typedef struct {
    // Ray Info
    vector_float3 origin;
    vector_float3 direction;
    vector_float3 color;
    
    // Ray's Pixel Index, Remaining Bounces
    vector_uint2 idx_bounces;
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
} Camera;


#endif /* PolluxTypes_h */
