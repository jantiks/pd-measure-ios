//
//  SCNHelper.swift
//  pd-measurer-ios
//
//  Created by Tigran Arsenyan on 10/3/21.
//

import Foundation
import SceneKit
import ARKit

class SCNHelper {
    
    static func normalizeVector(_ iv: SCNVector3) -> SCNVector3 {
        let length = sqrt(iv.x * iv.x + iv.y * iv.y + iv.z * iv.z)
        if length == 0 {
            return SCNVector3(0.0, 0.0, 0.0)
        }

        return SCNVector3( iv.x / length, iv.y / length, iv.z / length)

    }
    
    static func getPixelInMmFrom(_ node: SCNNode, sceneView: ARSCNView ,startVector: SCNVector3, endVector: SCNVector3) -> Float {
        
        let startWorldVec = node.convertPosition(startVector, to: sceneView.scene.rootNode)
        let endWorldVec = node.convertPosition(endVector, to: sceneView.scene.rootNode)
        let startProjectedVec = sceneView.projectPoint(startWorldVec)
        let endProjectedVec = sceneView.projectPoint(endWorldVec)
        let startPoint = CGPoint(x: CGFloat(startProjectedVec.x), y: CGFloat(startProjectedVec.y))
        let endPoint = CGPoint(x: CGFloat(endProjectedVec.x), y: CGFloat(endProjectedVec.y))
        let pixelInCm = (SCNHelper.distanceFrom(vector: startWorldVec, toVector: endWorldVec) * 1000) / Float(SCNHelper.CGPointDistance(from: endPoint, to: startPoint))
        
        return pixelInCm
    }
    
    static func distanceFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> Float {
        let x0 = vector1.x
        let x1 = vector2.x
        let y0 = vector1.y
        let y1 = vector2.y
        let z0 = vector1.z
        let z1 = vector2.z
        
        return sqrtf(powf(x1-x0, 2) + powf(y1-y0, 2) + powf(z1-z0, 2))
    }
    
    static func CGPointDistanceSquared(from: CGPoint, to: CGPoint) -> CGFloat {
        return (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
    }

    static func CGPointDistance(from: CGPoint, to: CGPoint) -> CGFloat {
        return sqrt(CGPointDistanceSquared(from: from, to: to))
    }
}
