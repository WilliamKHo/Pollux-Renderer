//
//  PlatformTypes.swift
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/24/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//
//  Defines a bunch of Types based on preprocessor flags determined
//  by the OS that's currently running. Allows my code to work with
//  all platforms with minimal compiler overhead.

import Foundation


#if os(iOS) || os(watchOS) || os(tvOS)
    import Foundation
    import UIKit
    typealias PlatformView                  = UIView
    typealias PlatformPoint                 = CGPoint
    typealias PlatformViewController        = UIViewController
    typealias PlatformPanGestureRecognizer  = UIPanGestureRecognizer
    typealias PlatformZoomGestureRecognizer = UIPinchGestureRecognizer
    typealias PlatformStoryboardSegue       = UIStoryboardSegue
    typealias PlatformColor                 = UIColor
#else
    import Cocoa
    import AppKit
    typealias PlatformView                  = NSView
    typealias PlatformPoint                 = NSPoint
    typealias PlatformViewController        = NSViewController
    typealias PlatformPanGestureRecognizer  = NSPanGestureRecognizer
    typealias PlatformZoomGestureRecognizer = NSMagnificationGestureRecognizer
    typealias PlatformStoryboardSegue       = NSStoryboardSegue
    typealias PlatformColor                 = NSColor
#endif
