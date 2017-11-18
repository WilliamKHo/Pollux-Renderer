//
//  SharedBuffer.swift
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/17/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Foundation
import Metal


class SharedBuffer <T>  {
    // Data Alignment
    private let alignment  : Int = 0x4000
    
    // Buffer Size
    var count  : Int
    
    var data : MTLBuffer?
    
    // Raw Pointer to the memory address of the first element
    private var memory:UnsafeMutableRawPointer? = nil
    
    // Pointer to the starting Element
    private var voidPtr: OpaquePointer!
    
    // Pointer to the starting Element
    private var startPtr: UnsafeMutablePointer<T>!
    
    // Pointer to the buffer -- Used to Index in
    private var bufferPtr: UnsafeMutableBufferPointer<T>!
    
    // Creates the Buffer
    init (count: Int, with device: MTLDevice) {
        // TODO: Do we really need the count variable?
        self.count = count
        
        var memoryByteSize  = count * MemoryLayout<Ray>.size.self
        let remainder = memoryByteSize % self.alignment
        memoryByteSize  = memoryByteSize + self.alignment - remainder
        
        // Assign Memory
        let error_code = posix_memalign(&memory, alignment, memoryByteSize)
        if error_code != 0 {
            // TODO: Improve Error code returned here to include type
            fatalError("makeBuffer error: could not allocate memory for buffer")
        }
        
        // Setup Pointers
        self.voidPtr = OpaquePointer(memory)
        self.startPtr    = UnsafeMutablePointer<T>(voidPtr)
        self.bufferPtr   = UnsafeMutableBufferPointer(start: startPtr, count: self.count)
        
        // Actually Create The Ray Buffer
        self.data = device.makeBuffer(bytesNoCopy: memory!,
                                                 length: memoryByteSize,
                                                 options: .storageModeShared,
                                                 deallocator: nil)
        
        if self.data == nil {
            // TODO: Improve Error code returned here to include type
            fatalError("makeBuffer error: could not make buffer for rays in setupRaysBuffer")
        }
    }
    
    public subscript(i: Int) -> T {
        return self.bufferPtr[i]
    }
    
    public func resize(count: Int, with device: MTLDevice) {
        // Free old memory
        free(memory)
    
        // Update Count
        self.count = count
    
        // Realign MemoryByteSize (Round up to neares multiple)
        var memoryByteSize = count * MemoryLayout<Ray>.size.self
        let remainder      = memoryByteSize % self.alignment
        memoryByteSize     = memoryByteSize + self.alignment - remainder
    
        // Assign Memory
        let error_code = posix_memalign(&memory, alignment, memoryByteSize)
        if error_code != 0 {
            // TODO: Improve Error code returned here to include type
            fatalError("makeBuffer error: could not allocate memory for buffer")
        }
        
        // Setup The Ray Buffer Again
        self.voidPtr     = OpaquePointer(memory)
        self.startPtr    = UnsafeMutablePointer<T>(voidPtr)
        self.bufferPtr   = UnsafeMutableBufferPointer(start: startPtr, count: self.count)
        
        // Actually Create The Ray Buffer
        self.data = device.makeBuffer(bytesNoCopy: memory!,
                                            length: memoryByteSize,
                                            options: .storageModeShared,
                                            deallocator: nil)
    }
    
    deinit {
        free(memory)
    }
}
