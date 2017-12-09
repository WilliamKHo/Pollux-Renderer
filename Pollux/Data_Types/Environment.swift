//
//  Environment.swift
//  Pollux
//
//  Created by William Ho on 12/6/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Foundation

struct Environment {
    var filename : String
    var emittance : float3
    
    init(from file: String, with emittance: float3) {
        self.filename = file
        self.emittance = emittance
    }
}

