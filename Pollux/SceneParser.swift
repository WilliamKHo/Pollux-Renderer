//
//  SceneParser.swift
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/21/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Foundation
import simd

class SceneParser {
    
    // Counts the types of lights (i.e. bsdfs < 0)
    private static var light_types = 0
    
    private static func parseCamera(_ cameraJSON : [String : Any]) -> Camera {
        var camera = Camera();
        camera.pos    = float3(cameraJSON["pos"] as! Array<Float>)
        camera.lookAt = float3(cameraJSON["lookAt"] as! Array<Float>)
        camera.up     = float3(cameraJSON["up"] as! Array<Float>)
        camera.data   = float4(0,0, cameraJSON["fov"] as! Float, cameraJSON["depth"] as! Float)
        
        // Actually Computing the view and right vectors here
        camera.view   = simd_normalize(camera.lookAt - camera.pos);
        camera.right  = simd_cross(camera.view, camera.up);
        
        return camera
    }
    
    private static func parseGeometry(_ geomsJSON : [[String : Any]]) -> ([Geom], UInt32) {
        var light_count : UInt32 = 0
        var geoms : [Geom] = [Geom]()
        for geomJSON in geomsJSON {
            var geom = Geom();
            geom.type = GeomType(geomJSON["type"] as! UInt32)
            geom.materialid  = geomJSON["material"] as! Int32
            geom.translation = float3(geomJSON["translate"] as! Array<Float>)
            geom.rotation    = float3(geomJSON["rotate"] as! Array<Float>)
            geom.scale       = float3(geomJSON["scale"] as! Array<Float>)
            let s_tr = simd_translation(dt: geom.translation)
            let s_rt = simd_rotation(dr:    geom.rotation)
            let s_sc = simd_scale(ds:       geom.scale)
            geom.transform = s_tr * s_rt * s_sc;
            geom.inverseTransform = simd_inverse(geom.transform)
            geom.invTranspose     = simd_transpose(geom.inverseTransform)
            
            light_count += (geom.materialid < light_types) ? 1 : 0;
            geoms.append(geom)
        }
        
        return (geoms, light_count)
    }
    
    private static func parseMaterials(_ materialsJSON : [[String : Any]]) -> [Material] {
        var materials : [Material] = [Material]()
        for materialJSON in materialsJSON {
            var material = Material();
            material.bsdf                = materialJSON["bsdf"] as? Int16 ?? 0
            material.color               = float3(materialJSON["color"] as? Array<Float> ?? [0.2, 0.2, 0.2])
            material.emittance           = float3(materialJSON["emittance"] as? Array<Float> ?? [0, 0, 0])
            material.hasReflective       = materialJSON["hasReflective"] as? Float ?? 0.0
            material.hasRefractive       = materialJSON["hasRefractive"] as? Float ?? 0.0
            material.index_of_refraction = materialJSON["index_of_refraction"] as? Float ?? 0.0
            material.specular_color      = float3(materialJSON["specular_color"] as? Array<Float> ?? [0, 0, 0])
            material.specular_exponent   = materialJSON["specular_exponent"] as? Float ?? 0.0
            
            self.light_types += (material.bsdf < 0) ? 1 : 0;
            
            materials.append(material)
        }
        
        return materials
    }
    
    static func parseScene(from file: String) -> (Camera, [Geom], UInt32, [Material]){
        #if os(iOS) || os(watchOS) || os(tvOS)
            let platform_file = "\(file)-ios"
        #else
            let platform_file = file
        #endif

        if let file = Bundle.main.url(forResource: platform_file, withExtension: "json") {
            do {
                let data      = try Data(contentsOf: file, options: [])
                let jsonFile  = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                let camera    = parseCamera(jsonFile["camera"] as! [String : Any])
                let materials = parseMaterials(jsonFile["materials"] as! [[String : Any]])
                let (geometry, light_count)  = parseGeometry(jsonFile["geometry"] as! [[String : Any]])
        
                return (camera, geometry, light_count, materials)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        } else {
            fatalError("Could not find scene file, please check file path and try again.")
        }
    }
}
