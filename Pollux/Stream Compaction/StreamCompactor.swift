//
//  StreamCompactor.swift
//  Pollux
//
//  Created by William Ho on 11/24/17.
//  Copyright © 2017 William Ho. All rights reserved.
//

import Cocoa

// Stream Compactor takes in a generic `T` parameter type and
// a corresponding kernel that applies a predicate to the
// buffer passed in
class StreamCompactor<T> {
    
    private enum CompactionStage {
        // Applies the passed in predicate function that
        // evaluates whether the given `T` is valid
        case APPLY_PREDICATE
        
        // Computes a standard prefix sum on the evaluated
        // buffer
        case PREFIX_SUM
    }
    
    // *********************
    // ***** GPU Data ******
    // *********************
    
    //References to device.
    private let device: MTLDevice
    private let defaultLibrary: MTLLibrary
    
    // Dynamic thread distribution based pipeline stage:
    // (see updateThreadGroups)
    private var threadsPerThreadgroup:MTLSize!
    private var threadgroupsPerGrid:MTLSize!
    
    // Indicates whether the buffers are already set in place
    // before compaction. False by default.
    private var buffersSet : Bool = false
    
    
    // *********************
    // **** Buffer Data ****
    // *********************
    private let items : SharedBuffer<T>
    
    
    
    // *********************
    // **** Kernel Data ****
    // *********************
    
    // Name of the kernel that applies the predicate to the array items
    // ------------------  implementation based -----------------------
    private let name_ApplyPredicate         : String
    // Kernel function pointer and pipeline state
    private var kern_ApplyPredicate         : MTLFunction?
    private var ps_ApplyPredicate           : MTLComputePipelineState! = nil
    
//    static var kernPrefixSumScan: MTLFunction?
//    static var kernPrefixSumScanPipelineState: MTLComputePipelineState! = nil
//
//    static var kernPrefixPostSumAddition: MTLFunction?
//    static var kernPrefixPostSumAdditionPipelineState: MTLComputePipelineState! = nil
//
//    static var kernScatter: MTLFunction?
//    static var kernScatterPipelineState: MTLComputePipelineState! = nil
//
//    static var kernCopyBack: MTLFunction?
//    static var kernCopyBackPipelineState: MTLComputePipelineState! = nil
    
    //Buffers
    private var validation_buffer: SharedBuffer<UInt32>!
//    private var scanThreadSums_buffer: SharedBuffer<UInt32>!

    
    // Initializes a `StreamCompactor` with the following params:
    //
    // items:           A `SharedBuffer<T>` containing the items
    //                  to be compacted
    //
    // device:          The device object which represents the GPU
    //
    // library:         The library containing the kernels
    //
    // predicateKernel: The name of the kernel which applies the predicate
    //                  to the buffer. predicate kernel's buffers must be
    //                  in the following format EXACTLY.
    //                  - count: number of items in the buffer       [[ buffer(0) ]]
    //                  - items: actual buffer items of type `T`     [[ buffer(2) ]]
    //
    // bufferSet:       A flag that indicates whether or not the buffers are already
    //                  set in place for our calculations. Saves having to reset buffers
    //                  for first stage. Defaults to false.
    //
    init(for items: SharedBuffer<T>,
         on device: MTLDevice,
         with library: MTLLibrary,
         applying predicateKernel: String) {
        self.items               = items
        self.device              = device
        self.defaultLibrary      = library
        self.name_ApplyPredicate = predicateKernel
        self.createHelperBuffers()
        
        // Setup compute pipeline
        do { try self.setupPipeline(on: self.device, with: self.defaultLibrary)}
        catch { fatalError("failed to creare computePipeline for streamCompaction")}
    }
    
    private func createHelperBuffers() {
        let twoPowerCeiling = ceilf(log2f(Float(self.items.count)))
        let validationBufferSize = Int(powf(2.0, twoPowerCeiling))
        validation_buffer = SharedBuffer(count: Int(validationBufferSize), with: device)
//        let numberOfSums = (validationBufferSize + kernApp.threadExecutionWidth * 2 - 1) / (kernEvaluateRaysPipelineState.threadExecutionWidth * 2)
//        scanThreadSums_buffer = SharedBuffer(count: numberOfSums, with: device)
    }
    
    // An all encompassing function that handles the entire Ray compaction phase
    func compact(using commandEncoder: MTLComputeCommandEncoder, buffersSet : Bool = false) {
        self.buffersSet = buffersSet
        
        // Apply the predicate
        self.dispatchPipelineStage(for: .APPLY_PREDICATE, using: commandEncoder)
        
        // Compute the prefix sum of validation buffer
        self.dispatchPipelineStage(for: .PREFIX_SUM, using: commandEncoder)
    }
    
    private func setupPipeline(on device: MTLDevice, with library: MTLLibrary) throws {
        kern_ApplyPredicate = library.makeFunction(name : self.name_ApplyPredicate)
        ps_ApplyPredicate   = try device.makeComputePipelineState(function : kern_ApplyPredicate!)
        
//        kernPrefixSumScan = library.makeFunction(name: "kern_prefixSumScan")
//        kernPrefixSumScanPipelineState = try device.makeComputePipelineState(function: kernPrefixSumScan!)
        
//        kernPrefixPostSumAddition = library.makeFunction(name: "kern_prefixPostSumAddition")
//        kernPrefixPostSumAdditionPipelineState = try device.makeComputePipelineState(function: kernPrefixPostSumAddition!)
//
//        kernScatter = library.makeFunction(name: "kern_scatterRays")
//        kernScatterPipelineState = try device.makeComputePipelineState(function: kernScatter!)
//
//        kernCopyBack = library.makeFunction(name: "kern_copyBack")
//        kernCopyBackPipelineState = try device.makeComputePipelineState(function: kernCopyBack!)
    }
    
    private func dispatchPipelineStage(for stage: CompactionStage, using commandEncoder: MTLComputeCommandEncoder) {
        self.setBuffers(for: stage, using: commandEncoder);
        self.updateThreadGroups(for: stage);
        
        switch (stage) {
        case .APPLY_PREDICATE:
            commandEncoder.setComputePipelineState(ps_ApplyPredicate)
            commandEncoder.dispatchThreadgroups(self.threadgroupsPerGrid,
                                                threadsPerThreadgroup: self.threadsPerThreadgroup)
        case .PREFIX_SUM:
            // TODO: Set compute Pipeline state and dispatch command for Prefix sum
            break
        }
    }
    
    private func setBuffers(for stage: CompactionStage, using commandEncoder: MTLComputeCommandEncoder) {
        switch (stage) {
        case .APPLY_PREDICATE:
            commandEncoder.setBuffer(validation_buffer.data, offset: 0, index: 1)
            // Only set items if they have not been set in the shader
            if (!self.buffersSet) {
                commandEncoder.setBytes(&items.count, length: MemoryLayout<Int>.size, index: 0)
                commandEncoder.setBuffer(items.data,  offset: 0, index: 2)
            }
        case .PREFIX_SUM:
            // TODO: Set buffers for prefix sum only if they have not been set before.
            break
        }
    }
    
    private func updateThreadGroups(for stage: CompactionStage) {
        switch (stage) {
        case .APPLY_PREDICATE:
            let warp_size = ps_ApplyPredicate.threadExecutionWidth
            self.threadsPerThreadgroup = MTLSize(width: warp_size,height:1,depth:1)
            self.threadgroupsPerGrid   = MTLSize(width: self.validation_buffer.count / warp_size, height:1, depth:1)
        case .PREFIX_SUM:
            // TODO: Update Threadgroup count for prefix sum stage
            break
        }
    }
    
//    static func setUpBuffers(count: Int, with device: MTLDevice) {
//        let twoPowerCeiling = ceilf(log2f(Float(count)))
//        validationBufferSize = Int(powf(2.0, twoPowerCeiling))
//        validation_buffer = SharedBuffer(count: Int(validationBufferSize), with: device)
//        let numberOfSums = (validationBufferSize + kernEvaluateRaysPipelineState.threadExecutionWidth * 2 - 1) / (kernEvaluateRaysPipelineState.threadExecutionWidth * 2)
//        scanThreadSums_buffer = SharedBuffer(count: numberOfSums, with: device)
//    }
    
//    private static func dispatchPipelineStage (for stage: CompactionStage, using commandEncoder: MTLComputeCommandEncoder) {
//        
//    }
    
//    static func encodeCompactCommands(inRays: SharedBuffer<Ray>, outRays: SharedBuffer<Ray>, using commandEncoder: MTLComputeCommandEncoder) {
//        var numberOfRays = UInt32(inRays.count)
//
//        // Set buffers and encode command to evaluate rays for termination
//        commandEncoder.setBuffer(inRays.data, offset: 0, index: 0)
//        commandEncoder.setBuffer(validation_buffer.data, offset: 0, index: 1)
//        commandEncoder.setBytes(&numberOfRays, length: MemoryLayout<UInt32>.stride, index: 2)
//        commandEncoder.setComputePipelineState(kernEvaluateRaysPipelineState)
//        var threadsPerGroup = MTLSize(width: kernEvaluateRaysPipelineState.threadExecutionWidth, height: 1, depth: 1)
//        var threadGroupsDispatched = MTLSize(width: (validationBufferSize + kernEvaluateRaysPipelineState.threadExecutionWidth - 1) / kernEvaluateRaysPipelineState.threadExecutionWidth, height: 1, depth: 1)
//        commandEncoder.dispatchThreadgroups(threadGroupsDispatched, threadsPerThreadgroup: threadsPerGroup)
//
//        //Set buffers for Prefix Sum Scan
//        commandEncoder.setBuffer(validation_buffer.data, offset: 0, index: 0)
//        commandEncoder.setBuffer(scanThreadSums_buffer.data, offset: 0, index: 1)
//        //Dispatch kernels for Prefix Sum Scan
//        commandEncoder.setComputePipelineState(kernPrefixSumScanPipelineState)
//        threadsPerGroup = MTLSize(width: kernEvaluateRaysPipelineState.threadExecutionWidth, height: 1, depth: 1)
//        threadGroupsDispatched = MTLSize(width: (validationBufferSize / 2 + kernEvaluateRaysPipelineState.threadExecutionWidth - 1) / kernEvaluateRaysPipelineState.threadExecutionWidth, height: 1, depth: 1)
//        commandEncoder.dispatchThreadgroups(threadGroupsDispatched, threadsPerThreadgroup: threadsPerGroup)
//
//        //Second pass if buffer size exceeds a single threadgroup
//        if (validationBufferSize > kernPrefixPostSumAdditionPipelineState.threadExecutionWidth * 2) {
//            commandEncoder.setBuffer(scanThreadSums_buffer.data, offset: 0, index: 0)
//            threadGroupsDispatched = MTLSize(width: 1, height: 1, depth: 1)
//            commandEncoder.dispatchThreadgroups(threadGroupsDispatched, threadsPerThreadgroup: threadsPerGroup)
//
//            commandEncoder.setComputePipelineState(kernPrefixPostSumAdditionPipelineState)
//            commandEncoder.setBuffer(validation_buffer.data, offset: 0, index: 0)
//            threadGroupsDispatched = MTLSize(width: (validationBufferSize / 2 - 1) / kernPrefixPostSumAdditionPipelineState.threadExecutionWidth, height: 1, depth: 1)
//            commandEncoder.dispatchThreadgroups(threadGroupsDispatched, threadsPerThreadgroup: threadsPerGroup)
//        }
//
//        //Set buffers for scatter
//        commandEncoder.setBuffer(inRays.data, offset: 0, index: 0)
//        commandEncoder.setBuffer(outRays.data, offset: 0, index: 1)
//        commandEncoder.setBuffer(validation_buffer.data, offset: 0, index: 2)
//        commandEncoder.setComputePipelineState(kernScatterPipelineState)
//        //Dispatch scatter kernel
//        threadsPerGroup = MTLSize(width: kernScatterPipelineState.threadExecutionWidth, height: 1, depth: 1)
//        threadGroupsDispatched = MTLSize(width: (inRays.count + kernScatterPipelineState.threadExecutionWidth - 1) / kernScatterPipelineState.threadExecutionWidth, height: 1, depth: 1)
//        commandEncoder.dispatchThreadgroups(threadGroupsDispatched, threadsPerThreadgroup: threadsPerGroup)
//
//        //Naively copy back wanted Rays
//        var rayCount: UInt32 = UInt32(inRays.count)
//        commandEncoder.setBytes(&rayCount, length: MemoryLayout<UInt32>.stride, index: 3)
//        commandEncoder.setComputePipelineState(kernCopyBackPipelineState)
//        commandEncoder.dispatchThreadgroups(threadGroupsDispatched, threadsPerThreadgroup: threadsPerGroup)
//
//    }
    // For debugging TODO: Remove this function
//    static func inspectBuffers() {
//        validation_buffer.inspectData()
//    }
    
}
