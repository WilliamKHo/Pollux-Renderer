//
//  MeshCreator.swift
//  Pollux
//
//  Created by Youssef Victor on 12/9/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Foundation

// Constants for Mesh Creation/Iteration
let maxDepth : UInt16  = 15
let maxNodes : UInt8   = 5

// A class that creates a mesh from a given OBJ file
final class MeshCreator {
    
    // Helper method to convert an array of doubles to a float3 simd type
    private static func arrayToFloat2(_ vector : [Double]?) -> float2? {
        // Deal with nil case and invalid vector case
        if (vector == nil) {
            return nil
        }
        
        // Dealing with smaller vectors (lesser dimensions?)
        let v1 = Float(vector!.count > 0 ? vector![0] : 0)
        let v2 = Float(vector!.count > 1 ? vector![1] : 0)
        
        // Convert to float3
        return float2(v1, v2)
    }
    
    // Helper method to convert an array of doubles to a float3 simd type
    private static func arrayToFloat3(_ vector : [Double]?) -> float3? {
        // Deal with nil case and invalid vector case
        if (vector == nil) {
            return nil
        }
        
        // Dealing with smaller vectors (lesser dimensions?)
        let v1 = Float(vector!.count > 0 ? vector![0] : 0)
        let v2 = Float(vector!.count > 1 ? vector![1] : 0)
        let v3 = Float(vector!.count > 2 ? vector![2] : 0)
        
        // Convert to float3
        return float3(v1, v2, v3)
    }
    
    static func createUseableMesh(from shape : Shape) -> ([Float], float3, float3) {
        var triangles : [Triangle] = []
        
        for face in shape.faces {
            if face.count < 3 {
                fatalError("Error in mesh creation: face has only two vertices")
            }
            
            for i in 1..<face.count-1 {
                // I assume here that the points and normals
                // must exist. That's because if you can't parse in
                // the points and normals then you might as well not
                // have a mesh. If you don't have a mesh, then the program
                // is inherently broken so just crash and end early.
                //
                // texCoords defaut to (0,0) because you'll only read from them if
                // you have a texture, therefore you can just throw in (0,0) in the
                // default case. Yes, this uses more memory on the GPU, but it
                // makes dealing with an optional type a lot easier across languages.
                
                let p1  = arrayToFloat3(face[0].vIndex != nil  ? shape.vertices[face[0].vIndex!]           : nil)
                let n1  = arrayToFloat3(face[0].nIndex != nil  ? shape.normals[face[0].nIndex!]            : nil)
                let t1  = arrayToFloat2(face[0].tIndex != nil  ? shape.textureCoords[face[0].tIndex!]      : nil) ?? float2(0)
                
                let p2  = arrayToFloat3(face[i].vIndex != nil  ? shape.vertices[face[i].vIndex!]           : nil)
                let n2  = arrayToFloat3(face[i].nIndex != nil  ? shape.normals[face[i].nIndex!]            : nil)
                let t2  = arrayToFloat2(face[i].tIndex != nil  ? shape.textureCoords[face[i].tIndex!]      : nil) ?? float2(0)
                
                let p3  = arrayToFloat3(face[i+1].vIndex != nil  ? shape.vertices[face[i+1].vIndex!]       : nil)
                let n3  = arrayToFloat3(face[i+1].nIndex != nil  ? shape.normals[face[i+1].nIndex!]        : nil)
                let t3  = arrayToFloat2(face[i+1].tIndex != nil  ? shape.textureCoords[face[i+1].tIndex!]  : nil) ?? float2(0)
                
                let bounds = AABB(simd_min(p1!, p2!, p3!), simd_max(p1!, p2!, p3!))
                
                triangles.append(Triangle(p1: p1!, p2: p2!, p3: p3!, n1: n1!, n2: n2!, n3: n3!, t1: t1, t2: t2, t3: t3, bounds: bounds))
            }
        }
        
        
        return Mesh(maxDepth, maxNodes, triangles).Compact()
    }
}
