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

func simd_translation(dt : float3) -> float4x4 {
    return float4x4(rows: [float4(1, 0, 0, dt.x),
                           float4(0, 1, 0, dt.y),
                           float4(0, 0, 1, dt.z),
                           float4(0, 0, 0,    1)])
}

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

func simd_scale(ds : float3) -> float4x4 {
    return float4x4(rows: [float4(ds.x,    0,    0, 0),
                           float4(   0, ds.y,    0, 0),
                           float4(   0,    0, ds.z, 0),
                           float4(   0,    0,    0, 1)])
}
