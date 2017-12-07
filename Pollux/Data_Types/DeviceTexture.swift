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

class DeviceTexture {
    var data : MTLTexture?
    
    init(from file: String, with device : MTLDevice) {
        let filenameArr = file.split(separator: ".", maxSplits: 2, omittingEmptySubsequences: false)
        let path = Bundle.main.path(forResource: String(filenameArr[0]), ofType: String(filenameArr[1]))
        let textureLoader = MTKTextureLoader(device: device)
        self.data = try! textureLoader.newTexture(URL: URL(fileURLWithPath: path!), options: [MTKTextureLoader.Option.textureStorageMode : (2 as NSNumber)]) // private storage mode
    }
}
