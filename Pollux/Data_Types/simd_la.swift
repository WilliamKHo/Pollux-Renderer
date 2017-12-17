//
//  simd_la.swift
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/21/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Foundation
import simd

/******************
 
 This is a linear algebra library built on top of
 the simd data types that are native to Swift.
 
 ******************/

// Returns a translation matrix based on a float3 vector indicating translation in all 3 dimensions
func simd_translation(dt : float3) -> float4x4 {
    return float4x4(rows: [float4(1, 0, 0, dt.x),
                           float4(0, 1, 0, dt.y),
                           float4(0, 0, 1, dt.z),
                           float4(0, 0, 0,    1)])
}

// Returns a rotation matrix based on a float3 vector indicating rotation (in degrees) across each axis
func simd_rotation(dr: float3) -> float4x4 {
    let dr = dr * Float.pi / 180.0;
    // Construct the matrices and return.
    let rx = float4x4(rows: [float4( 1,          0,          0, 0),
                             float4( 0, cosf(dr.x),-sinf(dr.x), 0),
                             float4( 0, sinf(dr.x), cosf(dr.x), 0),
                             float4( 0,          0,          0, 1)]);
    
    let ry = float4x4(rows: [float4( cosf(dr.y), 0, sinf(dr.y), 0),
                             float4(          0, 1,          0, 0),
                             float4(-sinf(dr.y), 0, cosf(dr.y), 0),
                             float4(          0, 0,          0, 1)]);
    
    let rz = float4x4(rows: [float4( cosf(dr.z),-sinf(dr.z), 0, 0),
                             float4( sinf(dr.z), cosf(dr.z), 0, 0),
                             float4(          0,          0, 1, 0),
                             float4(          0,          0, 0, 1)]);
    
    return rz * ry * rx;
}

// Returns a scale matrix based on a float3 vector indicating scale across all three dimensions
func simd_scale(ds : float3) -> float4x4 {
    return float4x4(rows: [float4(ds.x,    0,    0, 0),
                           float4(   0, ds.y,    0, 0),
                           float4(   0,    0, ds.z, 0),
                           float4(   0,    0,    0, 1)])
}

// Returns the component-wise minimum of two vectors
func simd_min(_ a : float3, _ b : float3) -> float3 {
    return float3(min(a.x,b.x), min(a.y,b.y), min(a.z,b.z))
}

// Returns the component-wise maximum of two vectors
func simd_max(_ a : float3, _ b : float3) -> float3 {
    return float3(max(a.x,b.x), max(a.y,b.y), max(a.z,b.z))
}

// Syntactic $ugar for returning the component-wise minimum of three vectors
func simd_min(_ a : float3, _ b : float3, _ c: float3) -> float3 {
    return simd_min(a, simd_min(b,c))
}

// Syntactic $ugar for returning the component-wise maximum of three vectors
func simd_max(_ a : float3, _ b : float3, _ c: float3) -> float3 {
    return simd_max(a, simd_max(b,c))
}
