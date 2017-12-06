////
////  StreamCompactor.swift
////  Pollux
////
////  Created by William Ho on 11/24/17.
////  Copyright © 2017 William Ho. All rights reserved.
////
//
//
//// General TODO's:
//// - Make a new command buffer or something
////   so you can make a command blit encoder and
////   be done with this shit
//
//import Metal
//import MetalKit
//
//let TG_SIZE = 64
//var sc_iter = 0
//
//// Stream Compactor takes in a generic `T` parameter type and
//// a corresponding kernel that applies a predicate to the
//// buffer passed in
//class StreamCompactor2D<T> {
//
//    private enum CompactionStage {
//        // Applies the passed in predicate function that
//        // evaluates whether the given `T` is valid
//        case APPLY_PREDICATE
//
//        // Computes a standard prefix sum on the evaluated
//        // buffer
//        case PREFIX_SUM
//
//        // Computes a standard prefix sum on the block_sums
//        // buffer
//        case PREFIX_SUM_OF_SUMS
//
//        // Computes a standard prefix sum on the evaluated
//        // sums of the each row, this is to sum up the
//        // columns
//        case PREFIX_SUM_FOR_Y
//
//        // Computes a standard prefix sum on the block_sums
//        // buffer of the VERTICAL ELEMENTS
//        case PREFIX_SUM_OF_SUMS_FOR_Y
//
//        // Computes a standard prefix sum on the block_sums
//        // buffer
//        case ADJUST_AND_SCATTER
//    }
//
//    // *********************
//    // ***** GPU Data ******
//    // *********************
//
//    //References to device.
//    private let device: MTLDevice
//    private let library: MTLLibrary
//
//    // Dynamic thread distribution based pipeline stage:
//    // (see updateThreadGroups)
//    private var threadsPerThreadgroup:MTLSize!
//    private var threadgroupsPerGrid:MTLSize!
//
//    // Indicates whether the buffers are already set in place
//    // before compaction. False by default.
//    private var buffersSet : Bool = false
//
//
//    // *********************
//    // **** Buffer Data ****
//    // *********************
//    private var items : MTLBuffer! = nil
//    private var size  : uint2      = uint2(1,1)
//    private let device_items : DeviceBuffer<T>
//    private let block_sums   : DeviceBuffer<uint>
//    private let sums_y       : DeviceBuffer<uint>
//    private let block_sums_y : DeviceBuffer<uint>
//
//
//    // *********************
//    // **** Kernel Data ****
//    // *********************
//
//    // The kernel that applies the predicate to the array items
//    private let name_ApplyPredicate         : String          // ----  implementation based ----
//    private var kern_ApplyPredicate         : MTLFunction!
//    private var ps_ApplyPredicate           : MTLComputePipelineState!
//
//    // Prefix Sum Calculation Stage
//    private var kern_PrefixSum              : MTLFunction!
//    private var ps_PrefixSum                : MTLComputePipelineState!
//
//    // Adds the accumulated sum of the block (adjustment) and scatters the new value
//    private var kern_AdjustAndScatter       : MTLFunction!
//    private var ps_AdjustAndScatter         : MTLComputePipelineState!
//
//    //Buffers
//    private var validation_buffer    : DeviceBuffer<uint>?
//    private var scan_result_buffer   : DeviceBuffer<uint>?
//
//    private var count_buffer         : SharedBuffer<uint>
//
//
//    // Whether or not to reverse the predicate evaluation
//    private var reverse_predicate    = false
//
//
//    // Initializes a `StreamCompactor` with the following params:
//    //
//    // items:           A `SharedBuffer<T>` containing the items
//    //                  to be compacted
//    //
//    // device:          The device object which represents the GPU
//    //
//    // library:         The library containing the kernels
//    //
//    // predicateKernel: The name of the kernel which applies the predicate
//    //                  to the buffer. predicate kernel's buffers must be
//    //                  in the following format EXACTLY.
//    //                  - count: number of items in the buffer       [[ buffer(0) ]]
//    //                  - items: actual buffer items of type `T`     [[ buffer(2) ]]
//    //
//    // bufferSet:       A flag that indicates whether or not the buffers are already
//    //                  set in place for our calculations. Saves having to reset buffers
//    //                  for first stage. Defaults to false.
//    //
//    init(on device: MTLDevice,
//         with library: MTLLibrary,
//         applying predicateKernel: String) {
//        self.device              = device
//        self.library             = library
//        self.name_ApplyPredicate = predicateKernel
//        self.device_items        = DeviceBuffer(count:  Int(self.size.x * self.size.y) , with: device)
//        self.block_sums          = DeviceBuffer(count: (Int(self.size.x * self.size.y) / TG_SIZE) + 1, with: device)
//        self.sums_y              = DeviceBuffer(count: (Int(self.size.y)          ) + 0, with: device)
//        self.block_sums_y        = DeviceBuffer(count: (Int(self.size.y) / TG_SIZE) + 1, with: device)
//
//        self.count_buffer        = SharedBuffer<uint>(count: 1, with: device,
//                                                      containing: [uint(self.device_items.count)])
//
//        self.createHelperBuffers()
//
//        // Setup compute pipeline
//        do { try self.setupPipeline()}
//        catch { fatalError("failed to creare computePipeline for streamCompaction")}
//    }
//
//    private func createHelperBuffers() {
//        let logCountCeiling = ceilf(log2f(Float(self.size.x * self.size.y)))
//        self.validation_buffer  = self.size.x > 1 ? DeviceBuffer(count: 1 << Int(logCountCeiling), with: device) : nil
//        self.scan_result_buffer = self.size.x > 1 ? DeviceBuffer(count: 1 << Int(logCountCeiling), with: device) : nil
//    }
//
//    // An all encompassing function that handles the entire stream compaction phase
//    func compact(_ buffer: MTLBuffer, of size: uint2, using commandEncoder: MTLComputeCommandEncoder, buffersSet : Bool = false, commandQueue: MTLCommandQueue) -> Int {
//        //DEBUG
//        sc_iter+=1
//
//        self.reverse_predicate   = false
//        self.items               = buffer
//        self.size                = size
//
//        self.buffersSet = buffersSet
//
//        // Ignore call if we still haven't initialized the buffers
//        if self.validation_buffer == nil { fatalError("invalid compact call"); }
//
//        for _ in 0..<2 {
//            // Apply the predicate
//            self.dispatchPipelineStage(for: .APPLY_PREDICATE, using: commandEncoder)
//
//            // Compute the prefix sum of validation buffer
//            self.dispatchPipelineStage(for: .PREFIX_SUM, using: commandEncoder)
//
//            // Compute the prefix sum of block_sums
//            self.dispatchPipelineStage(for: .PREFIX_SUM_OF_SUMS, using: commandEncoder)
//
//            // Compute the prefix sum of validation buffer
//            self.dispatchPipelineStage(for: .PREFIX_SUM_FOR_Y, using: commandEncoder)
//
//            // Compute the prefix sum of block_sums
//            self.dispatchPipelineStage(for: .PREFIX_SUM_OF_SUMS_FOR_Y, using: commandEncoder)
//
//            // Scatter the valid items to a new temporary array
//            self.dispatchPipelineStage(for: .ADJUST_AND_SCATTER, using: commandEncoder)
//
//            // Copy from buffer to buffer
//            self.copyBack(using: commandQueue.makeCommandBuffer())
//
//            // Reverses predicate and loops again
//            self.reverse_predicate = true
//            self.buffersSet = false
//            // Skip second round if there's nothing to be done
//            if (self.device_items.count == Int(self.size.x * self.size.y)) {
//                self.copyBack(using: commandQueue.makeCommandBuffer())
//                break;
//            }
//        }
//
////        self.dispatchPipelineStage(for: .DEBUG, using: commandEncoder)
//        return self.device_items.count
//    }
//
//    private func copyBack(using commandBuffer : MTLCommandBuffer?) {
//        let blitCommandEncoder = commandBuffer?.makeBlitCommandEncoder()!
//
//        if !reverse_predicate {
//            blitCommandEncoder?.copy(from: self.scan_result_buffer!.data!,
//                                 sourceOffset: (self.device_items.count - 1) * MemoryLayout<uint>.size,
//                                 to: self.count_buffer.data!,
//                                 destinationOffset: 0,
//                                 size: MemoryLayout<uint>.size)
//        } else {
//            // Copy new rays to old buff
//            blitCommandEncoder?.copy(from: self.device_items.data!,
//                                     sourceOffset: 0,
//                                     to: self.items,
//                                     destinationOffset: 0,
//                                     size: self.device_items.count * MemoryLayout<T>.size)
//        }
//        blitCommandEncoder?.endEncoding()
//        commandBuffer?.commit()
//        commandBuffer?.waitUntilCompleted()
//        if reverse_predicate {
//            let nc = Int(self.count_buffer[0])
//            self.device_items.count = nc == 0 ? self.device_items.count : nc
//            print("Setting Count to: \(self.device_items.count)")
//        }
//    }
//
//    // Resize the buffers
//    func resize(size: uint2) {
//        self.size = size
//        let logCountCeiling = ceilf(log2f(Float(self.size.x * self.size.y)))
//        if self.validation_buffer == nil {
//            self.validation_buffer = DeviceBuffer(count: 1 << Int(logCountCeiling), with: self.device)
//            self.scan_result_buffer = DeviceBuffer(count: 1 << Int(logCountCeiling), with: self.device)
//        } else {
//            self.validation_buffer!.resize (count: 1 << Int(logCountCeiling), with: self.device)
//            self.scan_result_buffer!.resize(count: 1 << Int(logCountCeiling), with: self.device)
//        }
//
//        // Resize the sums of the individual blocks.
//        // This count should be less than 64 * rows
//        self.block_sums.resize(count: (self.validation_buffer!.count) / TG_SIZE, with: self.device)
//
//        // Resize the copy buffer of items that is on the device
//        self.device_items.resize(count: Int(self.size.x * self.size.y), with: self.device)
//
//        // Resize the higher order dimension (y in this implementation) stuff
//        let logCountCeiling_y = ceilf(log2f(Float(self.size.y)))
//        self.sums_y.resize(count:        (1 << Int(logCountCeiling_y)          ) + 0, with: device)
//        self.block_sums_y.resize(count: (1 << Int(logCountCeiling_y) / TG_SIZE) + 1, with: device)
//
//        // Reset count buffer JIC
//        self.count_buffer[0] = uint(self.device_items.count)
//    }
//
//    private func setupPipeline() throws {
//        kern_ApplyPredicate   = self.library.makeFunction(name : self.name_ApplyPredicate)
//        ps_ApplyPredicate     = try self.device.makeComputePipelineState(function : kern_ApplyPredicate!)
//
//        kern_PrefixSum        = self.library.makeFunction(name: "kern_PrefixSum")
//        ps_PrefixSum          = try self.device.makeComputePipelineState(function: kern_PrefixSum!)
//
//        kern_AdjustAndScatter = self.library.makeFunction(name: "kern_AdjustAndScatter")
//        ps_AdjustAndScatter   = try device.makeComputePipelineState(function: kern_AdjustAndScatter!)
//    }
//
//    private func dispatchPipelineStage(for stage: CompactionStage, using commandEncoder: MTLComputeCommandEncoder) {
//        self.setBuffers(for: stage, using: commandEncoder);
//        self.updateThreadGroups(for: stage);
//
//        switch (stage) {
//        case .APPLY_PREDICATE:
//            commandEncoder.setComputePipelineState(ps_ApplyPredicate)
//            commandEncoder.dispatchThreadgroups(self.threadgroupsPerGrid,
//                                                threadsPerThreadgroup: self.threadsPerThreadgroup)
//
//        case .PREFIX_SUM, .PREFIX_SUM_OF_SUMS, .PREFIX_SUM_FOR_Y, .PREFIX_SUM_OF_SUMS_FOR_Y:
//            commandEncoder.setComputePipelineState(ps_PrefixSum)
//            commandEncoder.dispatchThreadgroups(self.threadgroupsPerGrid,
//                                                threadsPerThreadgroup: self.threadsPerThreadgroup)
//
//        case .ADJUST_AND_SCATTER      /* , .DEBUG   */  :
//            commandEncoder.setComputePipelineState(ps_AdjustAndScatter)
//            commandEncoder.dispatchThreadgroups(self.threadgroupsPerGrid,
//                                                threadsPerThreadgroup: self.threadsPerThreadgroup)
//            break
//        }
//    }
//
//    private func setBuffers(for stage: CompactionStage, using commandEncoder: MTLComputeCommandEncoder) {
//        switch (stage) {
//        case .APPLY_PREDICATE:
//            // The buffer we will fill up with the applied predicate
//            commandEncoder.setBuffer(validation_buffer!.data, offset: 0, index: 1)
//            commandEncoder.setBytes(&self.reverse_predicate, length: MemoryLayout<Bool>.size, index: 9)
//            // Only set items if they have not been set in the shader
//            if (!self.buffersSet) {
//                // Count of items we will run apply predicate & prefix sum on
//                var count = (self.size.x * self.size.y)
//                commandEncoder.setBytes(&count, length: MemoryLayout<Int>.size, index: 0)
//                // The items to use to apply predicate
//                commandEncoder.setBuffer(items,  offset: 0, index: 2)
//            }
//        // Adds the "block_sums" buffer AS OUTPUT to the prefix sum scan
//        case .PREFIX_SUM:
//            commandEncoder.setBuffer(scan_result_buffer!.data, offset: 0, index: 3)
//            commandEncoder.setBuffer(block_sums.data, offset: 0, index: 4)
//
//            // Write Stage: 1 - Overwrite Buffer
//            var write_y : UInt32 = 1
//            commandEncoder.setBytes(&write_y, length: MemoryLayout<UInt32>.size, index: 5)
//            commandEncoder.setBuffer(sums_y.data, offset: 0, index: 6)
//
//        // Adds the "block_sums" buffer AS INPUT to the prefix m scan
//        case .PREFIX_SUM_OF_SUMS:
//            // How may block_sums you should run a prefix scan on
//            commandEncoder.setBytes(&block_sums.count, length: MemoryLayout<Int>.size, index: 0)
//            commandEncoder.setBuffer(block_sums.data,  offset: 0, index: 1)
//            commandEncoder.setBuffer(block_sums.data,  offset: 0, index: 3)
//
//            // Write Stage: 2 - Add To Buffer
//            var write_y : UInt32 = 2
//            commandEncoder.setBytes(&write_y, length: MemoryLayout<UInt32>.size, index: 5)
//            break
//        case .PREFIX_SUM_FOR_Y:
//            commandEncoder.setBytes(&sums_y.count, length: MemoryLayout<Int>.size, index: 0)
//            commandEncoder.setBuffer(sums_y.data,  offset: 0, index: 1)
//            commandEncoder.setBuffer(sums_y.data,  offset: 0, index: 3)
//            commandEncoder.setBuffer(block_sums_y.data, offset: 0, index: 4)
//
//            // Write Stage: 0 - Don't Write
//            var write_y : UInt32 = 0
//            commandEncoder.setBytes(&write_y, length: MemoryLayout<UInt32>.size, index: 5)
//            break
//        case .PREFIX_SUM_OF_SUMS_FOR_Y:
//            // Set Buffers to block sums of Y
//            commandEncoder.setBytes(&block_sums_y.count, length: MemoryLayout<Int>.size, index: 0)
//            commandEncoder.setBuffer(block_sums_y.data,  offset: 0, index: 1)
//            commandEncoder.setBuffer(block_sums_y.data,  offset: 0, index: 3)
//            break
//        case .ADJUST_AND_SCATTER:
//            var count = (self.size.x * self.size.y)
//            commandEncoder.setBytes(&count, length: MemoryLayout<Int>.size, index: 0)
//            commandEncoder.setBuffer( validation_buffer!.data,  offset: 0, index: 1)
//            commandEncoder.setBuffer(                   items,  offset: 0, index: 2)
//            commandEncoder.setBuffer(scan_result_buffer!.data,  offset: 0, index: 3)
//            commandEncoder.setBuffer(         block_sums.data,  offset: 0, index: 4)
//
//            // Offset the invalids if we are in the reverse predicate round
//            let device_offset = reverse_predicate ? (device_items.count) * MemoryLayout<T>.size : 0
//
//            commandEncoder.setBuffer(       device_items.data,  offset: device_offset, index: 5)
//            commandEncoder.setBuffer(             sums_y.data,  offset: 0, index: 6)
//            commandEncoder.setBuffer(       block_sums_y.data,  offset: 0, index: 7)
//            break
////        case .DEBUG:
////            commandEncoder.setBuffer(self.count_buffer.data, offset: 0, index: 10)
////            break
//        }
//    }
//
//    private func updateThreadGroups(for stage: CompactionStage) {
//        switch (stage) {
//        case .APPLY_PREDICATE:
//            let warp_size = ps_ApplyPredicate.threadExecutionWidth
//            self.threadsPerThreadgroup = MTLSize(width: warp_size ,height:1,depth:1)
//            self.threadgroupsPerGrid   = MTLSize(width: self.validation_buffer!.count / warp_size, height:1, depth:1)
//        case .PREFIX_SUM:
//            self.threadsPerThreadgroup = MTLSize(width: TG_SIZE,height:1,depth:1)
//            let gridWidth              = self.validation_buffer!.count / (TG_SIZE*Int(self.size.y))
//            self.threadgroupsPerGrid   = MTLSize(width: gridWidth, height:Int(self.size.y), depth:1)
//            break
//        case .PREFIX_SUM_OF_SUMS:
//            let threadgroupWidth       = Int(self.size.x)      / TG_SIZE
//            let gridWidth              = self.block_sums.count / (threadgroupWidth*Int(self.size.y))
//
//            self.threadsPerThreadgroup = MTLSize(width: threadgroupWidth , height: 1, depth:1)
//            self.threadgroupsPerGrid   = MTLSize(width: gridWidth, height: Int(self.size.y), depth:1)
//            break
//
//        case .PREFIX_SUM_FOR_Y:
//            // 1D, so no height
//            self.threadsPerThreadgroup = MTLSize(width: TG_SIZE,height:1,depth:1)
//            self.threadgroupsPerGrid   = MTLSize(width: (Int(self.size.y) / TG_SIZE) + 1, height: 1, depth:1)
//            break
//
//        case .PREFIX_SUM_OF_SUMS_FOR_Y:
//            // TODO: Set Threadgroup count for S of S
//            let threadgroupWidth       = min(self.block_sums_y.count, TG_SIZE)
//            self.threadsPerThreadgroup = MTLSize(width: threadgroupWidth,height:1,depth:1)
//            self.threadgroupsPerGrid   = MTLSize(width: 1, height: 1, depth:1)
//            break
//
//        case .ADJUST_AND_SCATTER     /*,.DEBUG   */      :
//            self.threadsPerThreadgroup = MTLSize(width: TG_SIZE,height:1,depth:1)
//            let gridWidth              = self.validation_buffer!.count / (TG_SIZE*Int(self.size.y))
//            self.threadgroupsPerGrid   = MTLSize(width: gridWidth, height:Int(self.size.y), depth:1)
//            break
//        }
//    }
//}

