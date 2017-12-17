//
//  LaunchViewController.swift
//  Pollux
//
//  Created by Youssef Victor on 12/10/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#if os(macOS)
    import Cocoa
#else
    import Foundation
    import UIKit
#endif

var data : [String : Any] = [:]

class LaunchViewController: PlatformViewController {
    
    #if os(macOS)
       @IBOutlet weak var loadingIndicator: NSProgressIndicator!
    #else
    
    #endif
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
       
        #if os(macOS)
            loadingIndicator.startAnimation(self)
        #else
            
        #endif
        
        DispatchQueue.main.async {
            // Load in Scene (asynchronously)
            data["scene"] = SceneParser.parseScene(from: scene_file)
            
            
            #if os(macOS)
                self.performSegue(withIdentifier: PlatformStoryboardSegue.Identifier(rawValue: "segueToRenderer"), sender: self)
                // Close old window
                self.view.window?.close()
            #else
                self.performSegue(withIdentifier: "segueToRenderer", sender: self)
            #endif
          
        }

    }
    
}
