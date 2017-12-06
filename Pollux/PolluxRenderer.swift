//
//  PolluxRenderer.swift
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/8/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Metal
import MetalKit
import simd


// TODO: Remove This Render Debug Value
var myview: MTKView?

class PolluxRenderer: NSObject {
    
    // "Macro" for MIS
    let MIS = true;
    
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
    private var region : MTLRegion
    private let blankBitmapRawData : [UInt8]
    
    // The iteration the renderer is on
    var iteration : Int = 0
    
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
    
//    private var rayCompactor : StreamCompactor2D<Ray>!
    
    private var ps_ShadeMaterials: MTLComputePipelineState!;
    private var kern_ShadeMaterials: MTLFunction!
    
    private var ps_FinalGather: MTLComputePipelineState!;
    private var kern_FinalGather: MTLFunction!
    
    
    /*****
    **
    **  Rays Shared Buffers
    **  These buffers are ping-ponged at every bounce calculation
    **
    ******/
    let rays : SharedBuffer<Ray>
//    var frame_ray_count : Int
    
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
    
    /******
     **
     **  Number of lights
     **
     ******/
    var light_count : UInt32;
    
    /*****
     **
     **  CPU/GPU Synchronization Stuff
     **
     ******/
    // MARK: SEMAPHORE CODE - Initialization
    let iterationSemaphore : DispatchSemaphore = DispatchSemaphore(value: Int(MaxBuffers))
    
    
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
        self.max_depth = UInt(camera.data[3])
        
        self.rays          = SharedBuffer<Ray>(count: Int(mtkView.frame.size.width * mtkView.frame.size.height), with: device)
        self.geoms         = SharedBuffer<Geom>(count: scene.1.count, with: device, containing: scene.1)
        self.materials     = SharedBuffer<Material>(count: scene.2.count, with: device, containing: scene.2)
        self.frame         = SharedBuffer<float4>(count: self.rays.count, with: self.device)
        self.intersections = SharedBuffer<Intersection>(count: self.rays.count, with: self.device)
        self.light_count   = 2; // TODO: Parse in from scene
        
        
//        self.frame_ray_count = self.rays.count
        
        super.init()
        
        // Sets up the Compute Pipeline that we'll be working with
        self.setupComputePipeline()
    }
    
    private func setupComputePipeline() {
        // Create Pipeline State for RayGenereration from Camera
        if (MIS) {
            self.kern_GenerateRaysFromCamera = defaultLibrary.makeFunction(name: "kern_GenerateRaysFromCameraMIS")
            do    { try ps_GenerateRaysFromCamera = device.makeComputePipelineState(function: kern_GenerateRaysFromCamera)}
            catch { fatalError("generateRaysFromCamera computePipelineState failed")}
        } else {
            self.kern_GenerateRaysFromCamera = defaultLibrary.makeFunction(name: "kern_GenerateRaysFromCamera")
            do    { try ps_GenerateRaysFromCamera = device.makeComputePipelineState(function: kern_GenerateRaysFromCamera)}
            catch { fatalError("generateRaysFromCamera computePipelineState failed")}
        }
        
        // Create Pipeline State for ComputeIntersection
        self.kern_ComputeIntersections = defaultLibrary.makeFunction(name: "kern_ComputeIntersections")
        do    { try ps_ComputeIntersections = device.makeComputePipelineState(function: kern_ComputeIntersections)}
        catch { fatalError("ComputeIntersections computePipelineState failed") }
        
        // Create Pipeline State for ShadeMaterials
        if (MIS) {
            self.kern_ShadeMaterials = defaultLibrary.makeFunction(name: "kern_ShadeMaterialsMIS")
            do    { try ps_ShadeMaterials = device.makeComputePipelineState(function: kern_ShadeMaterials)}
            catch { fatalError("ShadeMaterials computePipelineState failed") }
        } else {
            self.kern_ShadeMaterials = defaultLibrary.makeFunction(name: "kern_ShadeMaterials")
            do    { try ps_ShadeMaterials = device.makeComputePipelineState(function: kern_ShadeMaterials)}
            catch { fatalError("ShadeMaterials computePipelineState failed") }
        }
        
        // Create Pipeline State for Ray Stream Compaction
//        self.rayCompactor = StreamCompactor2D<Ray>(on: device,
//                                                 with: defaultLibrary,
//                                                 applying: "kern_EvaluateRays")
        
        // Create Pipeline State for Final Gather
        self.kern_FinalGather = defaultLibrary.makeFunction(name: "kern_FinalGather")
        do    { try ps_FinalGather = device.makeComputePipelineState(function: kern_FinalGather)}
        catch { fatalError("FinalGather computePipelineState failed ") }
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
            self.threadsPerThreadgroup = MTLSize(width: min(self.rays.count, warp_size),height:1,depth:1)
            self.threadgroupsPerGrid   = MTLSize(width: max(self.rays.count / warp_size,1), height:1, depth:1)
        }
    }
    
    fileprivate func setBuffers(for stage: PipelineStage, using commandEncoder: MTLComputeCommandEncoder, at depth: Int) {
        //let rays = (depth % 2 == 0) ? self.rays1 : self.rays2
        //let rays = self.rays1
        switch (stage) {
        case GENERATE_RAYS:
            commandEncoder.setBytes(&self.camera, length: MemoryLayout<Camera>.size, index: 0)
            commandEncoder.setBytes(&self.max_depth, length: MemoryLayout<UInt>.size, index: 1)
            commandEncoder.setBuffer(rays.data, offset: 0, index: 2)
        case COMPUTE_INTERSECTIONS:
            // TODO: Setup buffer for intersections shader
            commandEncoder.setBytes(&self.rays.count, length: MemoryLayout<Int>.size, index: 0)
            commandEncoder.setBytes(&self.geoms.count,  length: MemoryLayout<Int>.size, index: 1)
            //commandEncoder.setBuffer(rays.data, offset: 0, index: 2)
            commandEncoder.setBuffer(self.intersections.data, offset: 0, index: 3)
            commandEncoder.setBuffer(self.geoms.data        , offset: 0, index: 4)
            break;
        case SHADE:
            // Buffer (0) is already set
            commandEncoder.setBytes(&self.iteration,  length: MemoryLayout<Int>.size, index: 1)
            // Buffer (2) is already set
            // Buffer (3) is already set
            // Buffer (4) is already set
            commandEncoder.setBuffer(self.materials.data, offset: 0, index: 5)
            if (MIS) {
                commandEncoder.setBytes(&self.geoms.count, length: MemoryLayout<Int>.size, index: 6);
                commandEncoder.setBytes(&self.light_count, length: MemoryLayout<Int>.size, index: 7);
            }
            break;
            
        case FINAL_GATHER:
//            commandEncoder.setBytes(&self.camera, length: MemoryLayout<Camera>.size, index: 0)
//            commandEncoder.setBytes(&self.iteration, length: MemoryLayout<UInt>.size, index: 1)
//            commandEncoder.setBuffer(self.rays.data, offset: 0, index: 2)
            commandEncoder.setBuffer(self.frame.data, offset: 0, index: 3)
            commandEncoder.setTexture(myview!.currentDrawable?.texture , index: 4)
            break;
         default:
            fatalError("Undefined Pipeline Stage Passed to SetBuffers")
        }
    }
    
    fileprivate func dispatchPipelineState(for stage: PipelineStage, using commandEncoder: MTLComputeCommandEncoder, at depth: Int) {
        setBuffers(for: stage, using: commandEncoder, at: depth);
        updateThreadGroups(for: stage);
        switch (stage) {
            case GENERATE_RAYS:
                commandEncoder.setComputePipelineState(ps_GenerateRaysFromCamera)
                commandEncoder.dispatchThreadgroups(self.threadgroupsPerGrid,
                                                    threadsPerThreadgroup: self.threadsPerThreadgroup)
            case COMPUTE_INTERSECTIONS:
                commandEncoder.setComputePipelineState(ps_ComputeIntersections)
                commandEncoder.dispatchThreadgroups(self.threadgroupsPerGrid,
                                                    threadsPerThreadgroup: self.threadsPerThreadgroup)
            case SHADE:
                commandEncoder.setComputePipelineState(ps_ShadeMaterials)
                commandEncoder.dispatchThreadgroups(self.threadgroupsPerGrid,
                                                    threadsPerThreadgroup: self.threadsPerThreadgroup)
            case COMPACT_RAYS:
                break;
            case FINAL_GATHER:
                commandEncoder.setComputePipelineState(ps_FinalGather)
                commandEncoder.dispatchThreadgroups(self.threadgroupsPerGrid,
                                                    threadsPerThreadgroup: self.threadsPerThreadgroup)
            default:
                fatalError("Undefined Pipeline Stage Passed to DispatchPipelineState")
        }
        commandEncoder.dispatchThreadgroups(self.threadgroupsPerGrid,
                                            threadsPerThreadgroup: self.threadsPerThreadgroup)
    }
    
    fileprivate func pathtrace(in view: MTKView) {
//        self.frame_ray_count = self.rays.count
        
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        commandBuffer?.label = "Iteration: \(iteration)"
        
        // MARK: SEMAPHORE CODE - Completion Handler
        commandBuffer?.addCompletedHandler({ _ in //unused parameter
//             This triggers the CPU that the GPU has finished work
//             this function is run when the GPU ends an iteration
//             Needed for CPU/GPU Synchronization
//             TODO: Semaphores
        self.iterationSemaphore.signal()
            print(self.iteration)
        })
        
        
        // If drawable is not ready, skip this iteration
        guard let drawable = view.currentDrawable
            else { // If drawable
                print("Drawable not ready for iteration #\(self.iteration)")
                return;
        }
        
        // Clear the drawable on the first iteration
        if (self.iteration == 0) {
            let blitCommandEnconder = commandBuffer?.makeBlitCommandEncoder()
            let frameRange = Range(0 ..< MemoryLayout<float4>.stride * self.frame.count)
            blitCommandEnconder?.fill(buffer: self.frame.data!, range: frameRange, value: 0)
            blitCommandEnconder?.endEncoding()
            
            drawable.texture.replace(region: self.region, mipmapLevel: 0, withBytes: blankBitmapRawData, bytesPerRow: bytesPerRow)
        }
        
        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        // If the commandEncoder could not be made
        if commandEncoder == nil || commandBuffer == nil {
            return
        }
        
        self.dispatchPipelineState(for: GENERATE_RAYS, using: commandEncoder!, at: 0)
        
        
        // Repeat Shading Steps `depth` number of times
        for _ in 0 ..< 8 { //Int(self.camera.data[3]) {
            self.dispatchPipelineState(for: COMPUTE_INTERSECTIONS, using: commandEncoder!, at: 0)

            self.dispatchPipelineState(for: SHADE, using: commandEncoder!, at: 0)

            // Stream Compaction for Terminated Rays
//            let size = uint2(UInt32(self.camera.data.x), UInt32(self.camera.data.y))
//            self.frame_ray_count = self.rayCompactor.compact(self.rays.data!, of: size, using: commandEncoder!, buffersSet: true, commandQueue: commandQueue)
        }
    
        self.dispatchPipelineState(for: FINAL_GATHER, using: commandEncoder!, at: 0)
        self.iteration += 1
        
        commandEncoder!.endEncoding()
        commandBuffer!.present(drawable)
        commandBuffer!.commit()
        // For stream compaction debugging purposes. TODO: Remove these completely
         commandBuffer!.waitUntilCompleted()
         //RayCompaction.inspectBuffers()
    }
}

extension PolluxRenderer : MTKViewDelegate {
    
    // Is called on each frame
    func draw(in view: MTKView) {
        // MARK: SEMAPHORE CODE - Wait
        // Wait until the last iteration is finished
        _ = self.iterationSemaphore.wait(timeout: DispatchTime.distantFuture)
        
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

        self.region = MTLRegionMake2D(0, 0, Int(view.frame.size.width), Int(view.frame.size.height))
        self.rays.resize(count: Int(size.width*size.height), with: self.device)
        self.intersections.resize(count: Int(size.width*size.height), with: self.device)
        self.frame.resize(count: Int(size.width*size.height), with: self.device)
//        self.rayCompactor.resize(size: uint2(UInt32(self.camera.data.x), UInt32(self.camera.data.y)))
        self.iteration = 0
    }
}

// MARK: Handles User Gestures
extension PolluxRenderer {
    
    // Pans the camera along it's right and up vectors by dt.x and -dt.y respectively
    func panCamera(by dt: PlatformPoint) {
        // Change pos values
        self.camera.pos += self.camera.right * Float(dt.x) / gestureDampening
        self.camera.pos -= self.camera.up    * Float(dt.y) / gestureDampening
        
        // Change the lookAt as well
        self.camera.lookAt += self.camera.right * Float(dt.x) / gestureDampening
        self.camera.lookAt -= self.camera.up    * Float(dt.y) / gestureDampening
        
        // Clear buffer by setting iteration = 0
        self.iteration = 0
    }
    
    // Zooms the camera along it's view vector by dz
    func zoomCamera(by dz: Float) {
        // Clear buffer by setting iteration = 0
        self.iteration = 0
    }
}

