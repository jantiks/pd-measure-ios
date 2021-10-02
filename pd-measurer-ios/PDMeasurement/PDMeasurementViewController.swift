//
//  PDMeasurementViewController.swift
//  pd-measurer-ios
//
//  Created by Tigran Arsenyan on 10/2/21.
//

import UIKit
import ARKit

class PDMeasurementViewController: UIViewController {
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet private weak var closeButton: UIButton!
    
    var distance: Float = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        startTracking()
        sceneView.delegate = self
        sceneView.session.delegate = self
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        sceneView.session.pause()
    }
    
    func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.startTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
    
    func distanceFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> Float {
        let x0 = vector1.x
        let x1 = vector2.x
        let y0 = vector1.y
        let y1 = vector2.y
        let z0 = vector1.z
        let z1 = vector2.z

        return sqrtf(powf(x1-x0, 2) + powf(y1-y0, 2) + powf(z1-z0, 2))
    }
    
    private func startTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        
        let configuration = ARFaceTrackingConfiguration()
        if #available(iOS 13.0, *) {
            configuration.maximumNumberOfTrackedFaces = ARFaceTrackingConfiguration.supportedNumberOfTrackedFaces
        }
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    @IBAction private func closeAction(_ sender: UIButton) {
        dismiss(animated: true)
    }
}

extension PDMeasurementViewController: ARSCNViewDelegate, ARSessionDelegate {
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer,
                  didUpdate node: SCNNode,
                  for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        // left eye vertical nodes
        let l1 = SCNVector3(faceAnchor.geometry.vertices[1107])
        let r1 = SCNVector3(faceAnchor.geometry.vertices[1062])

        let l2 = SCNVector3(faceAnchor.geometry.vertices[1094])
        let r2 = SCNVector3(faceAnchor.geometry.vertices[1075])

        let l3 = SCNVector3(faceAnchor.geometry.vertices[1108])
        let r3 = SCNVector3(faceAnchor.geometry.vertices[1063])

        let l4 = SCNVector3(faceAnchor.geometry.vertices[1095])
        let r4 = SCNVector3(faceAnchor.geometry.vertices[1076])

        let m1 = distanceFrom(vector: l1, toVector: r1)
        let m2 = distanceFrom(vector: l2, toVector: r2)
        let m3 = distanceFrom(vector: l3, toVector: r3)
        let m4 = distanceFrom(vector: l4, toVector: r4)
        
        let average = (m1 + m2 + m3 + m4) / 4
        
        // face angle
//        let faceZeroVectorInRootNode = self.sceneView.scene.rootNode.convertPosition(SCNVector3Zero, to: node)
//        let magnitude = sqrt(faceZeroVectorInRootNode.x * faceZeroVectorInRootNode.x + faceZeroVectorInRootNode.z * faceZeroVectorInRootNode.z)
//        let cosOfFaceVector = faceZeroVectorInRootNode.x / magnitude

//        distance = distanceFrom(vector: self.sceneView.scene.rootNode.convertPosition(SCNVector3Zero, to: node), toVector: SCNVector3Zero) * 1000
        
        print("AVERAGE IS \(average)")
    }
}
