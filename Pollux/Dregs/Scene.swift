//
//  Scene.swift
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/15/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Foundation

class Scene : SceneDelegate {
    
    // The Scene's Camera
    var camera : Camera
    
    init (screen: CGSize, depth: Float, iterations: Int, fov: Float, position: float3, lookAt: float3, up: float3) {
        self.camera = Camera()
        camera.data = float4(Float(screen.width), Float(screen.height), fov, depth)
        camera.pos  = position
        camera.lookAt = lookAt
        camera.up     = up
        camera.view   = simd_normalize(camera.lookAt - camera.pos);
        camera.right  = simd_cross(camera.view, camera.up);
    }
    
    func moveCamera(delta: float3) {
        // TODO: Implement camera movement
        
    }
}
