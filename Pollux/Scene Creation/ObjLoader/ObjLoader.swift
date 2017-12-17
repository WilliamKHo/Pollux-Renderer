//
//  ObjLoader.swift
//  SwiftObjLoader
//
//  Created by Hugo Tunius on 02/09/15.
//  Updated to Swift 4.0 by Youssef Victor on 12/09/2017
//  Copyright © 2015 Hugo Tunius. All rights reserved.
//

import Foundation

enum ObjLoadingError: Error {
    case UnexpectedFileFormat(error: String)
}


public final class ObjLoader {
    // Represent the state of parsing
    // at any point in time
    class State {
        var objectName: NSString?
        var vertices: [Vector] = []
        var normals: [Vector] = []
        var textureCoords: [Vector] = []
        var faces: [[VertexIndex]] = []
        var material: OBJMaterial?
    }

    // Source markers
    private static let commentMarker         = "#"
    private static let vertexMarker          = "v"
    private static let normalMarker          = "vn"
    private static let textureCoordMarker    = "vt"
    private static let objectMarker          = "o"
    private static let groupMarker           = "g"
    private static let faceMarker            = "f"
    private static let materialLibraryMarker = "mtllib"
    private static let useMaterialMarker     = "usemtl"

    private let scanner: ObjScanner
    private let basePath: NSString
    private var materialCache: [NSString: OBJMaterial] = [:]

    private var state = State()
    private var vertexCount = 0
    private var normalCount = 0
    private var textureCoordCount = 0

    // Init an objloader with the
    // source of the .obj file as a string
    //
    public init(source: String, basePath: NSString) {
        scanner = ObjScanner(source: source)
        self.basePath = basePath
    }

    // Read the specified source.
    // This operation is singled threaded and
    // should not be invoked again before
    // the call has returned
    public func read() throws -> [Shape] {
        var shapes: [Shape] = []

        resetState()

        do {
            while scanner.dataAvailable {
                let marker = scanner.readMarker()

                guard let m = marker, m.length > 0 else {
                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isComment(m) {
                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isVertex(m) {
                    if let v = try readVertex() {
                        state.vertices.append(v)
                    }

                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isNormal(m) {
                    if let n = try readVertex() {
                        state.normals.append(n)
                    }

                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isTextureCoord(m) {
                    if let vt = scanner.readTextureCoord() {
                        state.textureCoords.append(vt)
                    }

                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isObject(m) {
                    if let s = buildShape() {
                        shapes.append(s)
                    }

                    state = State()
                    state.objectName = scanner.readLine()
                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isGroup(m) {
                    if let s = buildShape() {
                        shapes.append(s)
                    }

                    state = State()
                    state.objectName = try scanner.readString()
                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isFace(m) {
                    if let indices = try scanner.readFace() {
                        state.faces.append(normalizeVertexIndices(unnormalizedIndices: indices))
                    }

                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isMaterialLibrary(m) {
                    let filenames = try scanner.readTokens()
                    try parseMaterialFiles(filenames)
                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isUseMaterial(m) {
                    let materialName = try scanner.readString()

                    guard let material = self.materialCache[materialName] else {
                        throw ObjLoadingError.UnexpectedFileFormat(error: "Material \(materialName) referenced before it was definied")
                    }

                    state.material = material
                    scanner.moveToNextLine()
                    continue
                }

                scanner.moveToNextLine()
            }

            if let s = buildShape() {
                shapes.append(s)
            }
            state = State()
        } catch let e {
            resetState()
            throw e
        }
        return shapes
    }

    private static func isComment(_ marker: NSString) -> Bool {
        return marker as String == commentMarker
    }

    private static func isVertex(_ marker: NSString) -> Bool {
        return marker.length == 1 && marker as String == vertexMarker
    }

    private static func isNormal(_ marker: NSString) -> Bool {
        return marker.length == 2 && marker as String == normalMarker
    }

    private static func isTextureCoord(_ marker: NSString) -> Bool {
        return marker.length == 2 && marker as String == textureCoordMarker
    }

    private static func isObject(_ marker: NSString) -> Bool {
        return marker.length == 1 && marker as String == objectMarker
    }

    private static func isGroup(_ marker: NSString) -> Bool {
        return marker.length == 1 && marker as String == groupMarker
    }

    private static func isFace(_ marker: NSString) -> Bool {
        return marker.length == 1 && marker as String == faceMarker
    }

    private static func isMaterialLibrary(_ marker: NSString) -> Bool {
        return marker as String == materialLibraryMarker
    }

    private static func isUseMaterial(_ marker: NSString) -> Bool {
        return marker as String == useMaterialMarker
    }

    private func readVertex() throws -> [Double]? {
        do {
            return try scanner.readVertex()
        } catch ScannerErrors.UnreadableData(let error) {
            throw ObjLoadingError.UnexpectedFileFormat(error: error)
        }
    }

    private func resetState() {
        scanner.reset()
        state = State()
        vertexCount = 0
        normalCount = 0
        textureCoordCount = 0
    }

    private func buildShape() -> Shape? {
        if state.vertices.count == 0 && state.normals.count == 0 && state.textureCoords.count == 0 {
            return nil
        }


        let result =  Shape(name: (state.objectName as String?), vertices: state.vertices, normals: state.normals, textureCoords: state.textureCoords, material: state.material, faces: state.faces)
        vertexCount += state.vertices.count
        normalCount += state.normals.count
        textureCoordCount += state.textureCoords.count

        return result
    }

    private func normalizeVertexIndices(unnormalizedIndices: [VertexIndex]) -> [VertexIndex] {
        return unnormalizedIndices.map {
            return VertexIndex(vIndex: ObjLoader.normalizeIndex(index: $0.vIndex, count: vertexCount),
                               nIndex: ObjLoader.normalizeIndex(index: $0.nIndex, count: normalCount),
                               tIndex: ObjLoader.normalizeIndex(index: $0.tIndex, count: textureCoordCount))
        }
    }

    private func parseMaterialFiles(_ filenames: [NSString]) throws {
        for filename in filenames {
            let fullPath = basePath.appendingPathComponent(filename as String)
            do {
                let fileContents = try NSString(contentsOfFile: fullPath,
                                                encoding: String.Encoding.utf8.rawValue)
                let loader = MaterialLoader(source: fileContents as String,
                                            basePath: basePath)

                let materials = try loader.read()

                for material in materials {
                    materialCache[material.name] = material
                }

            } catch MaterialLoadingError.UnexpectedFileFormat(let msg) {
                throw ObjLoadingError.UnexpectedFileFormat(error: msg)
            } catch {
                throw ObjLoadingError.UnexpectedFileFormat(error: "Invalid material file at \(fullPath)")
            }
        }
    }

    private static func normalizeIndex(index: Int?, count: Int) -> Int? {
        guard let i = index else {
            return nil
        }

        if i == 0 {
            return 0
        }

        return i - count - 1
    }
}
