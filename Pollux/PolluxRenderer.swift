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
    private let blankBitmapRawData : [UInt8]
    
    // TODO: Remove This Debug Value
    private var frameCount : Int = 0
    
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
    let rays : SharedBuffer<Ray>
    
    /*****
     **
     **  Geom Buffer Infos
     **
     ******/
    let geoms      : SharedBuffer<Geom>
    let geomsCount : Int
    
    let colors : SharedBuffer<float4>
    
    /*****
     **
     **  Camera & Camera Buffer
     **
     ******/
    var camera       : Camera
    var cameraBuffer : MTLBuffer
    
    /********************************
    *********************************
    ** ACTUAL SIMULATION VARIABLES **
    *********************************
    *********************************/
    var currentDepth     : UInt       = 0
    var traceDepthBuffer : MTLBuffer
    
    /// Initialize with the MetalKit view from which we'll obtain our Metal device.  We'll also use this
    /// mtkView object to set the pixelformat and other properties of our drawable
    init(with mtkView: MTKView) {
        self.device = mtkView.device!;
        self.commandQueue = device.makeCommandQueue();
        self.defaultLibrary = device.makeDefaultLibrary()!
        
        // TODO: delet this:
        myview = mtkView
        
        // Tell the MTKView that we want to use other buffers to draw
        mtkView.framebufferOnly = false
        
        // Indicate we would like to use the RGBAPisle format.
        mtkView.colorPixelFormat = .bgra8Unorm
        
        //Some Other Stuff
        mtkView.sampleCount = 1
        mtkView.preferredFramesPerSecond = 60
        
        // TODO: Create dynamic geometry size
        self.geomsCount = 4
        
        self.blankBitmapRawData = [UInt8](repeating: 0, count: Int(mtkView.frame.size.width * mtkView.frame.size.height * 4))
        
        // Initialize Camera:
        let width  = Float(mtkView.frame.size.width)
        let height = Float(mtkView.frame.size.height)
        self.camera = Camera(data: float4(width, height, FOV, DEPTH),
                             pos: float3(0.0, 5, 10.5),
                             lookAt: float3(0.0, 5, 0),
                             view: float3(0),
                             right: float3(0),
                             up: float3(0, 1, 0))
        // Actually Computing the view and right vectors here
        self.camera.view   = simd_normalize(camera.lookAt - camera.pos);
        self.camera.right  = simd_cross(camera.view, camera.up);
        
        // Set up the buffer for the camera
        self.cameraBuffer  = device.makeBuffer(bytes: &self.camera, length: MemoryLayout<Camera>.size, options: [])!
        
        // Set up the buffer for the trace depth
        self.traceDepthBuffer = device.makeBuffer(bytes: &self.currentDepth, length: MemoryLayout<UInt>.size, options: [])!
        
        self.rays  = SharedBuffer<Ray>(count: Int(mtkView.frame.size.width * mtkView.frame.size.height), with: device)
        self.geoms = SharedBuffer<Geom>(count: self.geomsCount, with: device)
        self.colors = SharedBuffer<float4>(count: self.rays.count, with: self.device)
        
        super.init()
        
        // Shouldn't have to deal with this rn
        // self.setupMaterialsBuffer()
        
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
    }
}


extension PolluxRenderer {
    
    fileprivate func pathtrace(in view: MTKView) {
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        commandBuffer?.label = "Iteration: \(frameCount)"
        frameCount += 1
        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        // If the commandEncoder could not be made
        if commandEncoder == nil || commandBuffer == nil {
            return
        }
        
        self.dispatchPipelineState(for: GENERATE_RAYS, using: commandEncoder!)
        
        //self.dispatchPipelineState(for: COMPUTE_INTERSECTIONS, using: commandEncoder!)
        
        // Stream Compaction for Terminated Rays
        // self.dispatchPipelineState(for: COMPACT_RAYS)
        
        //self.dispatchPipelineState(for: SHADE, using: commandEncoder!)
        
       // self.dispatchPipelineState(for: FINAL_GATHER, using: commandEncoder!)
        
        guard let drawable = view.currentDrawable else
        {
            Swift.print("currentDrawable returned nil")
            return
        }
        
        commandEncoder!.endEncoding()
        commandBuffer!.present(drawable)
        commandBuffer!.commit()
    }
    
    fileprivate func updateThreadGroups(for stage: PipelineStage) {
        // If we are currently generating rays or coloring the buffer,
        // Set up the threadGroups to loop over all pixels in the image (2D)
        if stage == GENERATE_RAYS || stage == FINAL_GATHER {
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
        if stage == COMPUTE_INTERSECTIONS || stage == SHADE {
            let warp_size = ps_GenerateRaysFromCamera.threadExecutionWidth
            self.threadsPerThreadgroup = MTLSize(width: warp_size,height:1,depth:1)
            self.threadgroupsPerGrid   = MTLSize(width: self.rays.count / warp_size, height:1, depth:1)
        }
    }
    
    fileprivate func setBuffers(for stage: PipelineStage, using commandEncoder: MTLComputeCommandEncoder) {
        switch (stage) {
        case GENERATE_RAYS:
            // TODO: Look into SetBytes Instead...
            commandEncoder.setBuffer(cameraBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(traceDepthBuffer, offset: 0, index: 1)
            commandEncoder.setBuffer(rays.data, offset: 0, index: 2)
            
            //Temporary code for this stage only
            // TODO: Remove this code
            commandEncoder.setBuffer(self.colors.data, offset: 0, index: 3)
            commandEncoder.setTexture(myview!.currentDrawable?.texture , index: 3)
            // TODO: End Remove
        case COMPUTE_INTERSECTIONS:
             // TODO: Setup buffer for intersections shader
            break;
        case SHADE:
           // TODO: Setup buffer for shading shader
            break;
        case FINAL_GATHER:
            // TODO: Setup buffer for final gather shader
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
}

extension PolluxRenderer : MTKViewDelegate {
    
    // Is called on each frame
    func draw(in view: MTKView) {
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
        
        // Remake the buffer
        self.cameraBuffer  = device.makeBuffer(bytes: &self.camera, length: MemoryLayout<Camera>.size, options: [])!

        // Resize Rays Buffer
        self.rays.resize(count: Int(size.width*size.height), with: self.device)
        self.colors.resize(count: Int(size.width*size.height), with: self.device)
    }
}
