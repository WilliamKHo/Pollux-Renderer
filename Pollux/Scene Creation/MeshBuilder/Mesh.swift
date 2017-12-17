//
//  Mesh.swift
//  Pollux
//
//  Created by Youssef Victor on 12/9/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

import Foundation


class Mesh {
    
    // MARK: Mesh Variables
    
    // The maximum depth of the mesh KD-tree
    let maxDepth : UInt16
    
    // The AABB of the mesh
    let meshBounds : AABB;
    
    // The maximum number of nodes in a leaf
    // by design limited to 255
    let maxNodes : UInt8;
    
    
    private var triangles : [Triangle]
    private var root : MeshNode
    
    
    // MARK: Compaction Variables
    // - These variables are needed to compact the mesh for
    //   GPU traversal
    //
    
    // The compacted Mesh Nodes
    var compactNodes : [Float]?;
    
    // The size of the compacted data
    var compactDataSize : Int = 0;
    
    // MARK: Mesh Functions
    
    init (_ maxDepth : UInt16, _ maxNodes : UInt8, _ triangles : [Triangle]) {
        self.maxDepth = maxDepth
        self.maxNodes = maxNodes
        self.triangles = triangles
        
        //Calculate AABB:
        
        var bounds = AABB()
        if (triangles.count > 0) {
            bounds = triangles[0].bounds;
        }
        
        for i in 0..<triangles.count {
            bounds = bounds.Encapsulate(triangles[i].bounds);
        }
        
        // Set AABB to encapsulation of bounds
        self.meshBounds = bounds
        
        // Create a temporary variable to pass into MeshNode. This is faster
        var tmp_tris = self.triangles
        
        self.root = MeshNode(&tmp_tris, meshBounds.bounds_min, meshBounds.bounds_max, 0, self.maxDepth, self.maxNodes);
        
//        print("Mesh Bounds: \nMin: \(bounds.bounds_min) \nMax: \(bounds.bounds_max)")
//        print("\(self.root.depth) tree depth");
//        print("\(self.root.nodeCount) tree nodes");
//        print("\(self.root.triangleCount) tree triangles");
    }
    
    func Compact() -> ([Float], float3, float3) {
        let nodeCount = self.root.nodeCount
        let triCount  = self.root.triangleCount
        
        // Left, right, split, axis, primitiveCount
        let nodeSize = 5
        
        // 6 (vectors) * 3 (vector_size)
        let triSize  = 18
        
        let compactDataCount = Int(nodeCount) * nodeSize + Int(triCount) * triSize
        self.compactDataSize = compactDataCount
        
        self.compactNodes = []
        self.compactNodes!.reserveCapacity(compactDataCount)
        
        var stack : [MeshNode] = [self.root]

        var offset = 0;
        
        while stack.count > 0 {
            
            let node : MeshNode = stack.popLast()!
            
            // If this node is the child of a parent, let's set the current offset
            if (node.parentOffset != -1) {
                compactNodes![Int(node.parentOffset)] = Float(offset);
            }
            
            // The current offset at this point in time
            let baseOffset = offset
            
            // Left Child's Index = -1
            compactNodes!.append(-1)
            
            // Right Child's Index = -1
            compactNodes!.append(-1)
            
            // Split point
            compactNodes!.append(node.split)
            
            // Split axis
            compactNodes!.append(Float(node.axis))
            
            if (node.isLeaf) {
                // Add count
                compactNodes!.append(Float(node.triangles.count))
                offset += 5;

                
                for i in 0..<node.triangles.count {
                    let triangle = node.triangles[i];
                    
                    let e1 = triangle.p2 - triangle.p1;
                    let e2 = triangle.p3 - triangle.p1;
//                    let p  = triangle.p1;
                    
                    // e1
                    compactNodes!.append(e1.x); offset+=1;
                    compactNodes!.append(e1.y); offset+=1;
                    compactNodes!.append(e1.z); offset+=1;
                    
                    // e2
                    compactNodes!.append(e2.x);  offset+=1;
                    compactNodes!.append(e2.y);  offset+=1;
                    compactNodes!.append(e2.z);  offset+=1;
                    
                    // p1
                    compactNodes!.append(triangle.p1.x); offset+=1;
                    compactNodes!.append(triangle.p1.y); offset+=1;
                    compactNodes!.append(triangle.p1.z); offset+=1;
                    
                    // Normals
                    compactNodes!.append(triangle.n1.x); offset+=1;
                    compactNodes!.append(triangle.n1.y); offset+=1;
                    compactNodes!.append(triangle.n1.z); offset+=1;
                    
                    compactNodes!.append(triangle.n2.x); offset+=1;
                    compactNodes!.append(triangle.n2.y); offset+=1;
                    compactNodes!.append(triangle.n2.z); offset+=1;
                    
                    compactNodes!.append(triangle.n3.x); offset+=1;
                    compactNodes!.append(triangle.n3.y); offset+=1;
                    compactNodes!.append(triangle.n3.z); offset+=1;
                }
            } else {
                // Append tricount
                compactNodes!.append(0)
                offset += 5;
                
                // Pass through the parent's offset to the children:
                node.left?.parentOffset  = Int32(baseOffset)
                node.right?.parentOffset = Int32(baseOffset + 1)
                
                // Append children to stack so we can go through them
                if node.left != nil {stack.append(node.left!)}
                if node.right != nil {stack.append(node.right!)}
            }
            
        }
        
        return (compactNodes ?? [], meshBounds.bounds_min, meshBounds.bounds_max)
    }

    /*************************
     *************************
     ***  KD-Tree MeshNode ***
     *************************
     *************************/
    
    // MARK: KD-Tree Constants:
    // Node Traversal Cost
    static private let K_t : Float = 1
    
    // Triangle Intersection cost
    static private let K_i : Float = 80
    
    // Steps we check against on the iteration across the dimension
    static private let STEPS : Float = 15
    
    // MARK: Private Internal Class called MeshNode
    private class MeshNode {
        
        // MARK: MeshNode Variables
        var triangles : [Triangle];
        // Left and Right Nodes
        var left         : MeshNode?;
        var right        : MeshNode?;
        
        // The axis to split on
        var axis         : Int;
        
        // The point along `axis` at which we split
        var split        : Float;
        
        // The offset of the parent node. To be used when compacting the KD-Tree
        var parentOffset : Int32;
        
        // MARK: MeshNode Functions
        //
        // - triangles: The triangles that will eventually be in the leafs
        // - nodeMin, nodeMax: The minimum and maximum points of the AABB of this node
        // - depth:  the depth of this node in the tree. The tree has a maximum of 2^16 depth.
        // - maxDepth: the maximum_depth of this node in the tree. The tree has a maximum of 2^16 depth.
        // - maxNodes: The maximum number of nodes possible in a leaf. Limited to 255 at most.
        init(_ triangles : inout [Triangle],
             _ nodeMin : float3, _ nodeMax : float3,
             _ depth   : UInt16, _ maxDepth : UInt16,
             _ maxNodes : UInt8) {
            
            let extent = abs(nodeMax - nodeMin);
            
            if (extent.x > extent.y && extent.x > extent.z) {
                self.axis = 0;
            } else if (extent.y > extent.x && extent.y > extent.z) {
                self.axis = 1;
            } else {
                self.axis = 2;
            }
            
             // Set to default values for now
            self.left  = nil
            self.right = nil
            self.split = 0;
            self.triangles = []
            
            // To be filled in Compact()
            self.parentOffset = -1;
            
            self.BuildNode(&triangles, nodeMin, nodeMax, depth, maxDepth, maxNodes);
        }
        
        /**
         * Main Function for the MeshNode
         * - Recursively builds a KD-Tree by splitting each child until
         *   termination condition is met.
         * - Called in initializor
         **/
        private func BuildNode(_ triangles : inout [Triangle],
                               _ nodeMin : float3, _ nodeMax : float3,
                               _ depth   : UInt16, _ maxDepth : UInt16,
                               _ threshold : UInt8) {
            
            // Termination Conditions:
            //
            // 1 - if triangles are less than the threshold set
            // 2 - if the depth >= maxDepth (too deep)
            // 3 - if the distance along axis we're splitting on is tiny
            //
            
            if (triangles.count > threshold && depth < maxDepth && abs(nodeMin[axis] - nodeMax[axis]) > SplitEpsilon) {
                
                // Get the Split Point between min & max along the `axis` dimension
                let p = self.GetSplitPoint(&triangles, nodeMin[axis], nodeMax[axis]);
                self.split = p
                
                // Split The Triangles
                var (leftShapes, rightShapes) = self.Split(along: p, using: &triangles)
                
                // Get New Bounds for Children by adjusting the `axis` dimension's value
                var leftMax  = nodeMax;    leftMax[axis]  = split;
                var rightMin = nodeMin;    rightMin[axis] = split;
                
                // Set Children
                self.left  = MeshNode(&leftShapes, nodeMin, leftMax, depth + 1, maxDepth, threshold);
                self.right = MeshNode(&rightShapes, rightMin, nodeMax, depth + 1, maxDepth, threshold);
            } else {
                // Termination Action / Base Case:
                // - Make this node a leaf
                
                self.triangles.append(contentsOf: triangles)
                self.left = nil
                self.right = nil
            }
        }
        
        private func lambda(_ l_count : inout Int, _ r_count : inout Int) -> Float {
            return (l_count == 0 || r_count == 0) ? 0.8 : 1.0
        }
        
        private func NodeCost(_ split : Float, _ triangles : inout [Triangle],
                              _ axisMin : Float, _ axisMax : Float) -> Float {
            // Cost of a Split `p` is determined to be:
            //
            // C(p) = K_t + K_i (SA(V_l)/ SA(V) * |T_l| +  SA(V_r)/ SA(V) * |T_r|)
            var N_l  = 0
            var N_r  = 0
            
            for tri in triangles
            {
                let bounds = tri.bounds;
                
                let p = bounds.bounds_center[axis];
                
                // If shape position is on right, surely its on right node
                if (p > split) {
                    N_r+=1;
                    
                    // But if bounding box collides with plane, add on left
                    // node
                    if (bounds.bounds_min[axis] <= split) {
                        N_l+=1;
                    }
                    
                }
                else {
                    N_l+=1;
                    
                    // But if bounding box collides with plane, add on right
                    // node
                    if (bounds.bounds_max[axis] >= split) {
                        N_r+=1;
                    }
                }
            }
            
            // A Simplification of Surface Area because all other dimensions are equal
            let SA_l = abs(axisMin - split)
            let SA_r = abs(split   - axisMax)
            let SA   = abs(axisMin - axisMax)
            
            
            // The bonus for empty nodes
            let lambda_p = lambda(&N_l, &N_r)
            let total_iteration_cost = Mesh.K_i * ((SA_l/SA) * Float(N_l) + (SA_r/SA) * Float(N_r))
            
            return lambda_p *  (Mesh.K_t + total_iteration_cost)
        }
        
        // A Surface Area Heuristic, that determines the best grouping among 3 splits
        //
        // - p: point at which we split the node
        // - N_l : Number of triangles in left split
        // - N_p : Number of triangles at split exactly
        // - N_r : Number of triangles in right split
        //
        // returns (Cost of Lesser Side, Lesser Side == Left)
        //        private func SAH(_ p : Float, _ N_l : Float, _ N_p : Float, _ N_r : Float) -> (Float, Bool) {
        //            let (SA_l, SA_r) = self.Split(at: p)
        //
        //            // Total Sum of Surface Areas of both Sides
        //            let SA = SA_l + SA_r
        //
        //            let P_l = SA_l / SA
        //            let P_r = SA_r / SA
        //
        //            // Costs of adding N_p to the left or the right
        //            let C_l = NodeCost(&P_l, &P_r, &(N_l + N_p), &N_r)
        //            let C_r = NodeCost(&P_l, &P_r, &(N_l), (&N_r + N_p))
        //
        //            let minCost = min(C_l, C_r)
        //            return (minCost, minCost == C_l)
        //        }
        
        private func Split(along split : Float, using triangles : inout [Triangle]) -> ([Triangle], [Triangle]){
            var leftShapes : [Triangle] = []
            var rightShapes : [Triangle] = []
            
            for tri in triangles {
                let bounds = tri.bounds;
                
                let p = bounds.bounds_center[axis];
                
                // If shape position is on right, surely its on right node
                if (p > split) {
                    rightShapes.append(tri);
                    
                    // But if bounding box collides with plane, add on left
                    // node
                    let min = bounds.bounds_min[axis];
                    
                    if (min <= split) {
                        leftShapes.append(tri);
                    }
                    
                }
                else {
                    leftShapes.append(tri);
                    
                    // But if bounding box collides with plane, add on right
                    // node
                    let max = bounds.bounds_max[axis];
                    
                    if (max >= split) {
                        rightShapes.append(tri);
                    }
                }
            }
            
            return (leftShapes, rightShapes)
        }
        
        private func GetSplitPoint(_ triangles : inout [Triangle],
                                   _ minAxis : Float, _ maxAxis : Float) -> Float {
            // Spatial median
            let center = (minAxis + maxAxis) * 0.5;
            
            // Object median
            var objMedian : Float = 0.0;
            
            for triangle in triangles {
                objMedian += triangle.bounds.bounds_center[axis];
            }
            
            objMedian /= Float(triangles.count);
            
            let step = (center - objMedian) / STEPS;
            
            var minCost = Float.greatestFiniteMagnitude;
            var result = objMedian;
            
            if (abs(step) > EPSILON)
            {
                // i is the proposed split point
                
                for i in stride(from: objMedian, through: center-1, by: step)
                {
                    let cost = NodeCost(i, &triangles, minAxis, maxAxis);
                    
                    if (minCost > cost)
                    {
                        minCost = cost;
                        result = i;
                    }
                }
            }
            
            return result;
        }
        
        // MARK: MeshNode Computed Properties
        // Returns the depth of this node in the tree
        var depth : UInt16 {
            if self.isLeaf {
                return 1;
            }
            
            return max(self.left?.depth ?? 0, self.right?.depth ?? 0) + 1;
        }
        
        // Returns whether or not this node is a leaf.
        var isLeaf : Bool {
            return self.left == nil && self.right == nil
        }
        
        // Returns the number of nodes under this MeshNode
        var nodeCount : UInt32 {
            if self.isLeaf {
                return 1
            }
            
            return (self.left?.nodeCount  ?? 0)  +
                (self.right?.nodeCount ?? 0) + 1
        }
        
        // Number of triangles in this Node
        var triangleCount : UInt64 {
            if self.isLeaf {
                return UInt64(self.triangles.count)
            }
            
            return (self.left?.triangleCount ?? 0)  +
                   (self.right?.triangleCount ?? 0)
        }
        
    }
}

