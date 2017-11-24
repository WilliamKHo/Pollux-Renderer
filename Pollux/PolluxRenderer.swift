//
//  PolluxRenderer.swift
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/8/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Cocoa
import Metal
import MetalKit
import simd

// TODO: Remove This Render Debug Value
var myview: MTKView?

class PolluxRenderer: NSObject {
    // Data Alignment
    private let alignment  : Int = 0x4000
    // Reference to the GPU essentially
    let device: MTLDevice
    // Default GPU Library
    private let defaultLibrary: MTLLibrary
    // The command Queue from which we'll obtain command buffers
    private let commandQueue: MTLCommandQueue!
    
    // Clear Color
    private let bytesPerRow : Int
    private let region : MTLRegion
    private let blankBitmapRawData : [UInt8]
    
    // The iteration the renderer is on
    private var iteration : Int = 0
    
    /****
    **
    **  GPU Kernels / Shader Stages
    **
    *****/
    private var threadsPerThreadgroup:MTLSize!
    private var threadgroupsPerGrid:MTLSize!
    
    // Our compute pipeline is analogous to a shader stage
    private var ps_GenerateRaysFromCamera: MTLComputePipelineState!;
    private var kern_GenerateRaysFromCamera: MTLFunction!
    
    private var ps_ComputeIntersections: MTLComputePipelineState!;
    private var kern_ComputeIntersections: MTLFunction!
    
    private var ps_ShadeMaterials: MTLComputePipelineState!;
    private var kern_ShadeMaterials: MTLFunction!
    
    private var ps_FinalGather: MTLComputePipelineState!;
    private var kern_FinalGather: MTLFunction!
    
    /*****
    **
    **  Rays Shared Buffer
    **
    ******/
    let rays1 : SharedBuffer<Ray>
    let rays2 : SharedBuffer<Ray>
    
    /*****
     **
     **  Geoms Shared Buffer
     **
     ******/
    let geoms      : SharedBuffer<Geom>
    
    /*****
     **
     **  Materials Shared Buffer
     **
     ******/
    let materials      : SharedBuffer<Material>
    
    /*****
     **
     **  Intersections Shared Buffer
     **
     ******/
    let intersections : SharedBuffer<Intersection>
    
    /*****
     **
     **  Camera & Camera Buffer
     **
     ******/
    var camera       : Camera
    
    /*****
     **
     **  Frame Shared Buffer
     **
     ******/
    let frame : SharedBuffer<float4>
    
    /*****
     **
     **  Simulation Variable(s)
     **
     ******/
    var max_depth : UInt;
    
    /*****
     **
     **  CPU/GPU Synchronization Stuff
     **
     ******/
    // MARK: SEMAPHORE CODE - Initialization
//    let iterationSemaphore : DispatchSemaphore = DispatchSemaphore(value: Int(MaxBuffers))
    
    
    /// Initialize with the MetalKit view from which we'll obtain our Metal device.  We'll also use this
    /// mtkView object to set the pixelformat and other properties of our drawable
    // TODO: Parse Scene
    init(in mtkView: MTKView, with scene: (Camera, [Geom], [Material])) {
        self.device = mtkView.device!;
        self.commandQueue = device.makeCommandQueue();
        self.defaultLibrary = device.makeDefaultLibrary()!
        
        // TODO: delet this:
        // needed for displaying texture for debug views
        myview = mtkView
        
        // Tell the MTKView that we want to use other buffers to draw
        // (needed for displaying from our own texture)
        mtkView.framebufferOnly = false
        
        // Indicate we would like to use the RGBAPisle format.
        mtkView.colorPixelFormat = .bgra8Unorm
        
        //Some Other Stuff
        mtkView.sampleCount = 1
        mtkView.preferredFramesPerSecond = 60

        // For Clearing the Frame Buffer
        self.bytesPerRow = Int(4 * mtkView.frame.size.width)
        self.region = MTLRegionMake2D(0, 0, Int(mtkView.frame.size.width), Int(mtkView.frame.size.height))
        self.blankBitmapRawData = [UInt8](repeating: 0, count: Int(mtkView.frame.size.width * mtkView.frame.size.height * 4))
        
        // Initialize Camera:
        let width  = Float(mtkView.frame.size.width)
        let height = Float(mtkView.frame.size.height)
        self.camera = scene.0
        camera.data.x = width
        camera.data.y = height
        self.max_depth = UInt(camera.data[2])
        
        self.rays1          = SharedBuffer<Ray>(count: Int(mtkView.frame.size.width * mtkView.frame.size.height), with: device)
        self.rays2          = SharedBuffer<Ray>(count: Int(mtkView.frame.size.width * mtkView.frame.size.height), with: device)
        self.geoms         = SharedBuffer<Geom>(count: scene.1.count, with: device, containing: scene.1)
        self.materials     = SharedBuffer<Material>(count: scene.2.count, with: device, containing: scene.2)
        self.frame         = SharedBuffer<float4>(count: self.rays1.count, with: self.device)
        self.intersections = SharedBuffer<Intersection>(count: self.rays1.count, with: self.device)
        
        super.init()
        
        // Sets up the Compute Pipeline that we'll be working with
        self.setupComputePipeline()
    }
    
    private func setupComputePipeline() {
        // Create Pipeline State for RayGenereration from Camera
        self.kern_GenerateRaysFromCamera = defaultLibrary.makeFunction(name: "kern_GenerateRaysFromCamera")
        do    { try ps_GenerateRaysFromCamera = device.makeComputePipelineState(function: kern_GenerateRaysFromCamera)}
        catch { fatalError("generateRaysFromCamera computePipelineState failed")}
        
        // Create Pipeline State for ComputeIntersection
        self.kern_ComputeIntersections = defaultLibrary.makeFunction(name: "kern_ComputeIntersections")
        do    { try ps_ComputeIntersections = device.makeComputePipelineState(function: kern_ComputeIntersections)}
        catch { fatalError("ComputeIntersections computePipelineState failed") }
        
        // Create Pipeline State for ShadeMaterials
        self.kern_ShadeMaterials = defaultLibrary.makeFunction(name: "kern_ShadeMaterials")
        do    { try ps_ShadeMaterials = device.makeComputePipelineState(function: kern_ShadeMaterials)}
        catch { fatalError("ShadeMaterials computePipelineState failed") }
        
        // Create Pipeline State for Final Gather
        self.kern_FinalGather = defaultLibrary.makeFunction(name: "kern_FinalGather")
        do    { try ps_FinalGather = device.makeComputePipelineState(function: kern_FinalGather)}
        catch { fatalError("FinalGather computePipelineState failed ") }
        
        RayCompaction.setUpOnDevice(self.device, library: defaultLibrary)
    }
}


extension PolluxRenderer {
    fileprivate func updateThreadGroups(for stage: PipelineStage) {
        // If we are currently generating rays or coloring the buffer,
        // Set up the threadGroups to loop over all pixels in the image (2D)
        if stage == GENERATE_RAYS {
            let w = ps_GenerateRaysFromCamera.threadExecutionWidth
            let h = ps_GenerateRaysFromCamera.maxTotalThreadsPerThreadgroup / w
            self.threadsPerThreadgroup = MTLSizeMake(w, h, 1)
            
            let widthInt  = Int(self.camera.data.x)
            let heightInt = Int(self.camera.data.y)
            self.threadgroupsPerGrid = MTLSize(width:  (widthInt + w - 1) / w,
                                               height: (heightInt + h - 1) / h,
                                               depth: 1)
        }
        // If we are currently computing the ray intersections, or shading those intersections,
        // Set up the threadgroups to go over all available rays (1D)
        else if stage == COMPUTE_INTERSECTIONS || stage == SHADE || stage == FINAL_GATHER {
            let warp_size = ps_ComputeIntersections.threadExecutionWidth
            self.threadsPerThreadgroup = MTLSize(width: warp_size,height:1,depth:1)
            self.threadgroupsPerGrid   = MTLSize(width: self.rays1.count / warp_size, height:1, depth:1)
        }
    }
    
    fileprivate func setBuffers(for stage: PipelineStage, using commandEncoder: MTLComputeCommandEncoder) {
        switch (stage) {
        case GENERATE_RAYS:
            commandEncoder.setBytes(&self.camera, length: MemoryLayout<Camera>.size, index: 0)
            commandEncoder.setBytes(&self.max_depth, length: MemoryLayout<UInt>.size, index: 1)
            commandEncoder.setBuffer(self.rays1.data, offset: 0, index: 2)
        case COMPUTE_INTERSECTIONS:
            // TODO: Setup buffer for intersections shader
            commandEncoder.setBytes(&self.rays1.count, length: MemoryLayout<Int>.size, index: 0)
            commandEncoder.setBytes(&self.geoms.count,  length: MemoryLayout<Int>.size, index: 1)
            //commandEncoder.setBytes(rays) not needed because it's already done in prev stage
            commandEncoder.setBuffer(self.intersections.data, offset: 0, index: 3)
            commandEncoder.setBuffer(self.geoms.data        , offset: 0, index: 4)
            break;
        case SHADE:
           // TODO: Setup buffer for shading shader
            // Buffer (0) is already set
            commandEncoder.setBytes(&self.iteration,  length: MemoryLayout<Int>.size, index: 1)
            // Buffer (2) is already set
            // Buffer (3) is already set
            commandEncoder.setBuffer(self.materials.data, offset: 0, index: 4)
            
            
            //Temporary code for this stage only
            // TODO: Remove this code
            
//            commandEncoder.setTexture(myview!.currentDrawable?.texture , index: 5)
//            var image = uint2(UInt32(self.camera.data.x), UInt32(self.camera.data.y))
//            commandEncoder.setBytes(&image, length: MemoryLayout<Camera>.size, index: 6)
//            // TODO: End Remove
            break;
        case FINAL_GATHER:
            // Buffer (0) is already set
            // Buffer (1) is already set
            // Buffer (2) is already set
            commandEncoder.setBuffer(self.frame.data, offset: 0, index: 3)
            commandEncoder.setTexture(myview!.currentDrawable?.texture , index: 4)
            break;
         default:
            fatalError("Undefined Pipeline Stage Passed to SetBuffers")
        }
    }
    
    fileprivate func dispatchPipelineState(for stage: PipelineStage,using commandEncoder: MTLComputeCommandEncoder) {
        setBuffers(for: stage, using: commandEncoder);
        updateThreadGroups(for: stage);
        switch (stage) {
            case GENERATE_RAYS:
                commandEncoder.setComputePipelineState(ps_GenerateRaysFromCamera)
            case COMPUTE_INTERSECTIONS:
                commandEncoder.setComputePipelineState(ps_ComputeIntersections)
            case SHADE:
                commandEncoder.setComputePipelineState(ps_ShadeMaterials)
            case FINAL_GATHER:
                commandEncoder.setComputePipelineState(ps_FinalGather)
            default:
                fatalError("Undefined Pipeline Stage Passed to DispatchPipelineState")
        }
        commandEncoder.dispatchThreadgroups(self.threadgroupsPerGrid,
                                            threadsPerThreadgroup: self.threadsPerThreadgroup)
    }
    
    fileprivate func pathtrace(in view: MTKView) {
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        commandBuffer?.label = "Iteration: \(iteration)"
        
        // MARK: SEMAPHORE CODE - Completion Handler
        // This triggers the CPU that the GPU has finished work
        // this function is run when the GPU ends an iteration
        // Needed for CPU/GPU Synchronization
        commandBuffer?.addCompletedHandler({ _ in //unused parameter
            print(self.iteration)
        })
        
        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        // If the commandEncoder could not be made
        if commandEncoder == nil || commandBuffer == nil {
            return
        }
        
        self.dispatchPipelineState(for: GENERATE_RAYS, using: commandEncoder!)
        
        
        // Repeat Shading Steps `depth` number of times
        for _ in 0 ..< Int(self.camera.data[3]) {
            
            self.dispatchPipelineState(for: COMPUTE_INTERSECTIONS, using: commandEncoder!)
            
            // Stream Compaction for Terminated Rays
            // self.dispatchPipelineState(for: COMPACT_RAYS)
            
            self.dispatchPipelineState(for: SHADE, using: commandEncoder!)
        }
        
        // If drawable is not ready, don't draw
        guard let drawable = view.currentDrawable
        else { // If drawable
            print("Drawable not ready for iteration #\(self.iteration)")
            commandEncoder!.endEncoding()
            commandBuffer!.commit()
            return;
        }
        
        // Clear the drawable on the first iteration
        if (self.iteration == 0) {
            drawable.texture.replace(region: self.region, mipmapLevel: 0, withBytes: blankBitmapRawData, bytesPerRow: bytesPerRow)
        }
        
        self.dispatchPipelineState(for: FINAL_GATHER, using: commandEncoder!)
        self.iteration += 1

        commandEncoder!.endEncoding()
        commandBuffer!.present(drawable)
        commandBuffer!.commit()
    }
    
}

extension PolluxRenderer : MTKViewDelegate {
    
    // Is called on each frame
    func draw(in view: MTKView) {
        // MARK: SEMAPHORE CODE - Wait
        // Wait until the last iteration is finished
//        _ = self.iterationSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        self.pathtrace(in: view)
    }
    
    // If the window changes, change the size of display
    // TODO: Blur Window while user drags?
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Save the size of the drawable as we'll pass these
        //   values to our vertex shader when we draw
        self.camera.data.x  = Float(size.width );
        self.camera.data.y  = Float(size.height);
        
        print(size)
        
        // Resize Rays Buffer
        self.rays1.resize(count: Int(size.width*size.height), with: self.device)
        self.intersections.resize(count: Int(size.width*size.height), with: self.device)
        self.frame.resize(count: Int(size.width*size.height), with: self.device)
    }
}
