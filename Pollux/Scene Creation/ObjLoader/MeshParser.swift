//
//  MeshParser.swift
//  Pollux
//
//  Created by Youssef Victor on 12/9/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Foundation

class MeshParser {
    private static var meshesLoading = 0
    private static let bundle = Bundle(for: MeshParser.self)
    
    static private func openOBJFile(_ filepath: String) throws -> String {
        guard let path = bundle.path(forResource: filepath, ofType: "obj") else {
            fatalError("OBJ File Not Found")
        }
        
        let string = try NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
        
        return string as String
    }
    
    static func parseMesh(_ filepath : String) -> ([Float], float3, float3) {
        // open up the file and get the contents
        let source = try? openOBJFile(filepath)
        
        let loader = ObjLoader(source: source!,
                               basePath: bundle.resourcePath! as NSString)
        
        do {
            let shapes = try loader.read()
            // Create Meshes from Shapes
            for shape in shapes {
                // Add a marker that there are meshes loading
               return (MeshCreator.createUseableMesh(from: shape))
            }
        } catch (let error){
            fatalError(error.localizedDescription)
        }
        
        return ([], float3(0), float3(0))
    }
}
