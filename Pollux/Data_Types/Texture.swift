//
//  DeviceTexture.swift
//  Pollux
//
//  Created by William Ho on 12/6/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Foundation
import Metal
import MetalKit

class Texture {
    
//    var width : Int
//    
//    var height : Int
//    
    var data : MTLTexture?
    
    init(with device : MTLDevice) {
//        self.height = height
//        self.width = width
        
        let path = Bundle.main.path(forResource: "environment1", ofType: "png")
        let textureLoader = MTKTextureLoader(device: device)
        self.data = try! textureLoader.newTexture(URL: URL(fileURLWithPath: path!), options: nil)
    }
}
