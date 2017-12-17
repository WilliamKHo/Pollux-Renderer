//
//  DeviceBuffer.swift
//  Pollux
//
//  Created by Youssef Victor on 11/28/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Foundation
import Metal

/*
 *  This is a class that provides a nice wrapper for creating
 *  buffers purely on the GPU. This class requires the SharedBuffer<T>
 *  class as well if you want to use the `contents` argument.
 *
 *  The way things work is by first creating a SharedBuffer<T> with the
 *  contents and then blitting the contents of that buffer to a buffer
 *  with a "private" storageMode (i.e. GPU access only)
 *
 */

class DeviceBuffer<T>  {
    // Buffer Size
    var count  : Int
    
    // The actual Buffer that stores the data
    var data : MTLBuffer?
    
    
    init (count: Int, with device: MTLDevice, containing contents : [T] = [], blitOn commandQueue: MTLCommandQueue? = nil) {
        self.count = count
        self.data = device.makeBuffer(length: count * MemoryLayout<T>.size.self, options: .storageModePrivate)
        
        // Create a temporary shared buffer to move data to/from
        if contents.count > 0 {
            let sharedBuffer = SharedBuffer<T>(count: self.count, with: device, containing: contents)
            
            let commandBuffer = commandQueue!.makeCommandBuffer()
            let blitCommandEncoder = commandBuffer?.makeBlitCommandEncoder()
            blitCommandEncoder?.copy(from: sharedBuffer.data!, sourceOffset: 0,
                                     to: self.data!, destinationOffset: 0,
                                     size: count * MemoryLayout<T>.size.self)
            blitCommandEncoder?.endEncoding()
            commandBuffer?.commit()
            commandBuffer?.waitUntilCompleted()
        }
    }
    
    public func resize(count: Int, with device: MTLDevice) {
        self.count = count
        self.data =  device.makeBuffer(length: self.count * MemoryLayout<T>.size.self, options: .storageModePrivate)
    }
}
