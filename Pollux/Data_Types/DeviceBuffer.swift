//
//  DeviceBuffer.swift
//  Pollux
//
//  Created by Youssef Victor on 11/28/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Foundation
import Metal


class DeviceBuffer <T>  {
    // Buffer Size
    var count  : Int
    
    // The actual Buffer that stores the data
    var data : MTLBuffer?
    
//    let memory  : UnsafeMutableRawPointer?
    
    
    init (count: Int, with device: MTLDevice, containing contents : [T] = []) {
        self.count = count
        self.data = device.makeBuffer(length: count * MemoryLayout<T>.size.self, options: .storageModePrivate)
        
        // TODO: Implement `containing` argument
//      let sharedBuffer = createTemporarySharedBuffer()
//      --- create command buffer ---
//      --- create blitcommandencoder--
//      copy from sharedBuffer to self.data
//      -- freeSharedBuffer?*
    }
    
      // TODO: Implement Subscript operator
//    public subscript(i: Int) -> T {
      // Create single sharedBuffer Element
      // --- copy from buffer to element ---
      // return element
//    }
    
    public func resize(count: Int, with device: MTLDevice) {
        self.count = count
        self.data =  device.makeBuffer(length: self.count * MemoryLayout<T>.size.self, options: .storageModePrivate)
    }
}
