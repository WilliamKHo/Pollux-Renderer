//
//  PathtracerViewController.swift
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/8/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Cocoa
import Metal
import MetalKit


// Defines what a ViewController is called because it differs from
//
#if os(iOS) || os(watchOS) || os(tvOS)
  import UIKit
  typealias PlatformViewController = UIViewController
#else
  import AppKit
  typealias PlatformViewController = NSViewController
#endif

class PolluxViewController: PlatformViewController {

    var metalView : MTKView?
    var renderer  : PolluxRenderer?
    
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
        let scene = SceneParser.parseScene(from: "cornellReflectionRefraction")
        
        //Initializes the Renderer
        renderer = PolluxRenderer(in: metalView!, with: scene)
        
        if(renderer == nil)
        {
            print("Renderer failed initialization");
            return;
        }
        
        self.metalView!.delegate = self.renderer;
        
        // Indicate that we would like the view to call our -[AAPLRender drawInMTKView:] 60 times per
        //   second.  This rate is not guaranteed: the view will pick a closest framerate that the
        //   display is capable of refreshing (usually 30 or 60 times per second).  Also if our renderer
        //   spends more than 1/60th of a second in -[AAPLRender drawInMTKView:] the view will skip
        //   further calls until the renderer has returned from that long -[AAPLRender drawInMTKView:]
        //   call.  In other words, the view will drop frames.  So we should set this to a frame rate
        //   that we think our renderer can consistently maintain.
        self.metalView!.preferredFramesPerSecond = 60;
    }
    
}
