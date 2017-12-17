//
//  MaterialLoader.swift
//  SwiftObjLoader
//
//  Created by Hugo Tunius on 04/10/15.
//  Updated to Swift 4.0 by Youssef Victor on 12/09/2017
//  Copyright © 2015 Hugo Tunius. All rights reserved.
//

import Foundation

public enum MaterialLoadingError: Error {
    case UnexpectedFileFormat(error: String)
}

public final class MaterialLoader {

    // Represent the state of parsing
    // at any point in time
    struct State {
        var materialName: NSString?
        var ambientColor: Color?
        var diffuseColor: Color?
        var specularColor: Color?
        var specularExponent: Double?
        var illuminationModel: IlluminationModel?
        var ambientTextureMapFilePath: NSString?
        var diffuseTextureMapFilePath: NSString?

        func isDirty() -> Bool {
            if materialName != nil {
                return true
            }

            if ambientColor != nil {
                return true
            }

            if diffuseColor != nil {
                return true
            }

            if specularColor != nil {
                return true
            }

            if specularExponent != nil {
                return true
            }

            if illuminationModel != nil {
                return true
            }

            if ambientTextureMapFilePath != nil {
                return true
            }

            if diffuseTextureMapFilePath != nil {
                return true
            }

            return false
        }
    }

    // Source markers
    private static let newMaterialMarker       = "newmtl"
    private static let ambientColorMarker      = "Ka"
    private static let diffuseColorMarker      = "Kd"
    private static let specularColorMarker     = "Ks"
    private static let specularExponentMarker  = "Ns"
    private static let illuminationModeMarker  = "illum"
    private static let ambientTextureMapMarker = "map_Ka"
    private static let diffuseTextureMapMarker = "map_Kd"

    private let scanner: MaterialScanner
    private let basePath: NSString
    private var state: State

    // Init an MaterialLoader with the
    // source of the .mtl file as a string
    //
    init(source: String, basePath: NSString) {
        self.basePath = basePath
        scanner = MaterialScanner(source: source)
        state = State()
    }

    // Read the specified source.
    // This operation is singled threaded and
    // should not be invoked again before
    // the call has returned
    func read() throws -> [OBJMaterial] {
        resetState()
        var materials: [OBJMaterial] = []

        do {
            while scanner.dataAvailable {
                let marker = scanner.readMarker()

                guard let m = marker, m.length > 0 else {
                    scanner.moveToNextLine()
                    continue
                }

                if MaterialLoader.isAmbientColor(m) {
                    let color = try readColor()
                    state.ambientColor = color

                    scanner.moveToNextLine()
                    continue
                }

                if MaterialLoader.isDiffuseColor(m) {
                    let color = try readColor()
                    state.diffuseColor = color

                    scanner.moveToNextLine()
                    continue
                }

                if MaterialLoader.isSpecularColor(m) {
                    let color = try readColor()
                    state.specularColor = color

                    scanner.moveToNextLine()
                    continue
                }

                if MaterialLoader.isSpecularExponent(m) {
                    let specularExponent = try readSpecularExponent()

                    state.specularExponent = specularExponent

                    scanner.moveToNextLine()
                    continue
                }

                if MaterialLoader.isIlluminationMode(m) {
                    let model = try readIlluminationModel()
                    state.illuminationModel = model

                    scanner.moveToNextLine()
                    continue
                }

                if MaterialLoader.isAmbientTextureMap(m) {
                    let mapFilename = try readFilename()
                    state.ambientTextureMapFilePath = basePath.appendingPathComponent(mapFilename as String) as NSString

                    scanner.moveToNextLine()
                    continue
                }

                if MaterialLoader.isDiffuseTextureMap(m) {
                    let mapFilename = try readFilename()
                    state.diffuseTextureMapFilePath = basePath.appendingPathComponent(mapFilename as String) as NSString

                    scanner.moveToNextLine()
                    continue
                }

                if MaterialLoader.isNewMaterial(m) {
                    if let material = try buildMaterial() {
                        materials.append(material)
                    }

                    state = State()
                    state.materialName = scanner.readLine()
                    scanner.moveToNextLine()
                    continue
                }
                _ = scanner.readLine()
                scanner.moveToNextLine()
                continue
            }

            if let material = try buildMaterial() {
                materials.append(material)
            }

            state = State()
        }

        return materials
    }

    private func resetState() {
        scanner.reset()
        state = State()
    }

    private static func isNewMaterial( _ marker: NSString) -> Bool {
        return marker as String == newMaterialMarker
    }

    private static func isAmbientColor( _ marker: NSString) -> Bool {
        return marker as String  == ambientColorMarker
    }

    private static func isDiffuseColor( _ marker: NSString) -> Bool {
        return marker as String  == diffuseColorMarker
    }

    private static func isSpecularColor( _ marker: NSString) -> Bool {
        return marker as String  == specularColorMarker
    }

    private static func isSpecularExponent( _ marker: NSString) -> Bool {
        return marker as String  == specularExponentMarker
    }

    private static func isIlluminationMode( _ marker: NSString) -> Bool {
        return marker as String  == illuminationModeMarker
    }

    private static func isAmbientTextureMap( _ marker: NSString) -> Bool {
        return marker as String  == ambientTextureMapMarker
    }

    private static func isDiffuseTextureMap( _ marker: NSString) -> Bool {
        return marker as String  == diffuseTextureMapMarker
    }

    private func readColor() throws -> Color {
        do {
            return try scanner.readColor()
        } catch ScannerErrors.InvalidData(let error) {
            throw MaterialLoadingError.UnexpectedFileFormat(error: error)
        } catch ScannerErrors.UnreadableData(let error) {
            throw MaterialLoadingError.UnexpectedFileFormat(error: error)
        }
    }

    private func readIlluminationModel() throws -> IlluminationModel {
        do {
            let value = try scanner.readInt()
            if let model = IlluminationModel(rawValue: Int(value)) {
                return model
            }

            throw MaterialLoadingError.UnexpectedFileFormat(error: "Invalid illumination model: \(value)")
        } catch ScannerErrors.InvalidData(let error) {
            throw MaterialLoadingError.UnexpectedFileFormat(error: error)
        }
    }

    private func readSpecularExponent() throws -> Double {
        do {
            let value = try scanner.readDouble()

            guard value >= 0.0 && value <= 1000.0 else {
                throw MaterialLoadingError.UnexpectedFileFormat(error: "Invalid Ns value: !(value)")
            }

            return value
        } catch ScannerErrors.InvalidData(let error) {
            throw MaterialLoadingError.UnexpectedFileFormat(error: error)
        }
    }

    private func readFilename() throws -> NSString {
        do {
            return try scanner.readString()
        } catch ScannerErrors.InvalidData(let error) {
            throw MaterialLoadingError.UnexpectedFileFormat(error: error)
        }
    }

    private func buildMaterial() throws -> OBJMaterial? {
        guard state.isDirty() else {
            return nil
        }

        guard let name = state.materialName else {
            throw MaterialLoadingError.UnexpectedFileFormat(error: "Material name required for all materials")
        }

        return OBJMaterial() {
            $0.name              = name
            $0.ambientColor      = self.state.ambientColor
            $0.diffuseColor      = self.state.diffuseColor
            $0.specularColor     = self.state.specularColor
            $0.specularExponent  = self.state.specularExponent
            $0.illuminationModel = self.state.illuminationModel
            $0.ambientTextureMapFilePath = self.state.ambientTextureMapFilePath
            $0.diffuseTextureMapFilePath = self.state.diffuseTextureMapFilePath

            return $0
        }
    }
}
