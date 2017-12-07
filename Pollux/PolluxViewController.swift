//
//  PathtracerViewController.swift
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/8/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//


import Metal
import MetalKit

class PolluxViewController: PlatformViewController {

    var metalView : MTKView?
    var renderer  : PolluxRenderer?
    
    // Gesture recognizors for Camera Movement
    var panGestureRecognizer = PlatformPanGestureRecognizer()
    var zoomGestureRecognizer = PlatformZoomGestureRecognizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view to use the default device
        self.metalView = self.view as? MTKView
        self.metalView?.device = MTLCreateSystemDefaultDevice();
        
        if(metalView?.device == nil)
        {
            print("Metal Is Not Supported On This Device");
            return;
        }
        
        // TODO: Improve Scene parsing
        let scene = SceneParser.parseScene(from: "cornell")
        
        //Initializes the Renderer
        renderer = PolluxRenderer(in: metalView!, with: scene)
        
        if(renderer == nil)
        {
            print("Renderer failed initialization");
            return;
        }
        
        self.metalView!.delegate = self.renderer;
        
        // Set up the pan gesture recognizer and it's action
        // This pans the camera if the user does a pan gesture
        self.panGestureRecognizer = PlatformPanGestureRecognizer(target: self, action: #selector(PolluxViewController.handlePan(_:)))
        self.metalView!.addGestureRecognizer(self.panGestureRecognizer)
        
        // Set up the pan gesture recognizer and it's action
        // This pans the camera if the user does a pan gesture
        self.zoomGestureRecognizer = PlatformZoomGestureRecognizer(target: self, action: #selector(PolluxViewController.handleZoom(_:)))
        self.metalView!.addGestureRecognizer(self.zoomGestureRecognizer)
        
        // Indicate that we would like the view to call our -[AAPLRender drawInMTKView:] 60 times per
        //   second.  This rate is not guaranteed: the view will pick a closest framerate that the
        //   display is capable of refreshing (usually 30 or 60 times per second).  Also if our renderer
        //   spends more than 1/60th of a second in -[AAPLRender drawInMTKView:] the view will skip
        //   further calls until the renderer has returned from that long -[AAPLRender drawInMTKView:]
        //   call.  In other words, the view will drop frames.  So we should set this to a frame rate
        //   that we think our renderer can consistently maintain.
        self.metalView!.preferredFramesPerSecond = 60;
    }
    
    
    @objc func handlePan(_ panGestureRecognizer : PlatformPanGestureRecognizer) {
        var dt = panGestureRecognizer.translation(in: myview!)
        self.panGestureRecognizer.setTranslation(PlatformPoint(x: 0, y: 0), in: myview!)
        #if os(iOS) || os(watchOS) || os(tvOS)
           dt.y = -dt.y
        #endif
        self.renderer?.panCamera(by: dt)
    }
    
    @objc func handleZoom(_ zoomGestureRecognizer : PlatformZoomGestureRecognizer) {
        #if os(iOS) || os(watchOS) || os(tvOS)
            let dz =  zoomGestureRecognizer.velocity
        #else
            let dz = zoomGestureRecognizer.magnification
            zoomGestureRecognizer.magnification = 0
        #endif
//        print(dz)
        self.renderer?.zoomCamera(by: Float(dz))
    }
}
