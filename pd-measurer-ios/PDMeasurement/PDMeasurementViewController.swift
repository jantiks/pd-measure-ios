//
//  PDMeasurementViewController.swift
//  pd-measurer-ios
//
//  Created by Tigran Arsenyan on 10/2/21.
//

import UIKit
import ARKit
import SceneKit

class PDMeasurementViewController: UIViewController {
    
    @IBOutlet private weak var sceneView: ARSCNView!
    @IBOutlet private weak var resultView: UIView!
    @IBOutlet private weak var farPdLabel: UILabel!
    @IBOutlet private weak var nearPdLabel: UILabel!
    @IBOutlet private weak var closeButton: UIButton!
    
    private var pupilLine: SCNNode? = nil
    private var zPositionDiff: CGFloat = 0
    private var blendShapes: [ARFaceAnchor.BlendShapeLocation : NSNumber] = [:]
    private var faceAngle: Float = 0
    private var scanTimer: Timer?
    private var deleteResultsTimer: Timer?
    private var pixelInMm: Float = 0
    private var pdResults: [CGFloat] = []
    private var isFirstMeasurement = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startTracking()
        sceneView.delegate = self
        sceneView.session.delegate = self
        scanTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(scanForFaces), userInfo: nil, repeats: true)
        deleteResultsTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(deleteResults), userInfo: nil, repeats: true)
        initUi()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        sceneView.session.pause()
        scanTimer?.invalidate()
        deleteResultsTimer?.invalidate()
    }
    
    private func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.startTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
    
    private func initUi() {
        resultView.layer.cornerRadius = 10
        resultView.alpha = 0.7
    }
    
    private func setNodes(_ node: SCNNode) {
        removeNodes()
        
        pupilLine = SCNNode()
        node.addChildNode(pupilLine!)
    }
    
    private func shouldScanFace() -> Bool {
        return isLookUpDownValid() && isFaceAngleValid() && pdResults.count < 20
    }
    
    private func isLookUpDownValid() -> Bool {
        return isLookUpValid() && isLookDownValid()
    }
    
    private func isLookUpValid() -> Bool {
        return (Float(truncating: self.blendShapes[.eyeLookUpLeft] ?? 0) < 0.12) && (Float(truncating: self.blendShapes[.eyeLookUpRight] ?? 0) < 0.12)
    }
    
    private func isLookDownValid() -> Bool {
        return (Float(truncating: self.blendShapes[.eyeLookDownLeft] ?? 0) < 0.12) && (Float(truncating: self.blendShapes[.eyeLookDownRight] ?? 0) < 0.12)
    }
    
    private func isFaceAngleValid() -> Bool {
        return faceAngle > -3 && faceAngle < 3
    }
    
    @objc private func deleteResults() {
        if pdResults.count >= 20 {
            pdResults.removeFirst()
        }
    }
    
    @objc
    private func scanForFaces() {
        guard shouldScanFace() else { return }
        //get the captured image of the ARSession's current frame
        let capturedImage = sceneView.snapshot()
        var orientation: Int32 = 0
        
        // detect image orientation, we need it to be accurate for the face detection to work
        switch capturedImage.imageOrientation {
        case .up:
            orientation = 1
        case .down:
            orientation = 3
        case .left:
            orientation = 8
        case .right:
            orientation = 6
        case .upMirrored:
            orientation = 2
        case .downMirrored:
            orientation = 4
        case .leftMirrored:
            orientation = 5
        case .rightMirrored:
            orientation = 7
        default:
            orientation = 1
        }
        
        let detectFaceRequest = VNDetectFaceLandmarksRequest { (request, error) in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                //Loop through the resulting faces and add a red UIView on top of them.
                if let faces = request.results as? [VNFaceObservation] {
                    for face in faces {
                        self.setPupilPositions(face, size: self.sceneView.frame.size)
                    }
                }
            }
        }
        
        DispatchQueue.global().async {
            try? VNImageRequestHandler(cgImage: capturedImage.cgImage!, orientation: CGImagePropertyOrientation(rawValue: CGImagePropertyOrientation.RawValue(orientation))!).perform([detectFaceRequest])
        }
    }
    
    private func setPupilPositions(_ face: VNFaceObservation, size: CGSize) {
        if isFirstMeasurement {
            isFirstMeasurement = false
            return
        }
        
        if let leftLandmark = face.landmarks?.leftPupil, let leftPoint = leftLandmark.normalizedPoints.first, let rightLandmark = face.landmarks?.rightPupil, let rightPoint = rightLandmark.normalizedPoints.first {
            
            // draw the face rect
            let affineTransform = CGAffineTransform(translationX: 0, y: size.height)
                .scaledBy(x: 1.0, y: -1.0)
            
            // draw the face rect
            let w = face.boundingBox.size.width * size.width
            let h = face.boundingBox.size.height * size.height
            let x = face.boundingBox.origin.x * size.width
            let y = face.boundingBox.origin.y * size.height
            let startPoint = CGPoint(x: x + CGFloat(leftPoint.x) * w, y: y + CGFloat(leftPoint.y) * h).applying(affineTransform)
            let endPoint = CGPoint(x: x + CGFloat(rightPoint.x) * w, y: y + CGFloat(rightPoint.y) * h).applying(affineTransform)
            
            pdResults.append(((SCNHelper.CGPointDistance(from: startPoint, to: endPoint)) * CGFloat(pixelInMm)) + zPositionDiff)
            
            updatePdNodes(getAveragePdResult())
        }
    }
    
    private func getAveragePdResult() -> CGFloat {
        guard pdResults.count > 0 else { return 0 }
        
        var averageResult: CGFloat = 0
        
        pdResults.forEach({ averageResult += CGFloat($0) })
        
        return averageResult / CGFloat(pdResults.count)
    }
    
    private func updatePdNodes(_ pd: CGFloat) {
        farPdLabel.text = "Far PD: \(String(format: "%.01f", pd))"
        nearPdLabel.text = "Near PD: \(String(format: "%.01f", pd - 3))"
    }
    
    private func removeNodes() {
        pupilLine?.removeFromParentNode()
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
    
    private func reset() {
        pdResults = []
        isFirstMeasurement = true
        farPdLabel.text = "Far PD: 0"
        nearPdLabel.text = "Near PD: 0"
        startTracking()
    }
    
    @IBAction private func closeAction(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    @IBAction func resetAction(_ sender: UIButton) {
        print("WORKED RESET")
        reset()
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
        
        DispatchQueue.main.async { [weak self] in
            self?.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARFaceAnchor else { return }
        
        setNodes(node)
    }
    
    func renderer(_ renderer: SCNSceneRenderer,
                  didUpdate node: SCNNode,
                  for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        blendShapes = faceAnchor.blendShapes
        
        // left eye vertical nodes
        let l1 = SCNVector3(faceAnchor.geometry.vertices[1107])
        let r1 = SCNVector3(faceAnchor.geometry.vertices[1062])
        
        let l2 = SCNVector3(faceAnchor.geometry.vertices[1094])
        let r2 = SCNVector3(faceAnchor.geometry.vertices[1075])
        
        let l3 = SCNVector3(faceAnchor.geometry.vertices[1108])
        let r3 = SCNVector3(faceAnchor.geometry.vertices[1063])
        
        let l4 = SCNVector3(faceAnchor.geometry.vertices[1095])
        let r4 = SCNVector3(faceAnchor.geometry.vertices[1076])
        
        let pixelInMm1 = SCNHelper.getPixelInMmFrom(node, sceneView: sceneView, startVector: l1, endVector: l2)
        let pixelInMm2 = SCNHelper.getPixelInMmFrom(node, sceneView: sceneView, startVector: l3, endVector: l4)
        let pixelInMm3 = SCNHelper.getPixelInMmFrom(node, sceneView: sceneView, startVector: r1, endVector: r2)
        let pixelInMm4 = SCNHelper.getPixelInMmFrom(node, sceneView: sceneView, startVector: r3, endVector: r4)
        
        pixelInMm = (pixelInMm1 + pixelInMm2 + pixelInMm3 + pixelInMm4) / Float(4)

        // face angle
        let faceZeroVectorInRootNode = self.sceneView.scene.rootNode.convertPosition(SCNVector3Zero, to: node)
        let magnitude = sqrt(faceZeroVectorInRootNode.x * faceZeroVectorInRootNode.x + faceZeroVectorInRootNode.z * faceZeroVectorInRootNode.z)
        let cosOfFaceVector = faceZeroVectorInRootNode.x / magnitude
        faceAngle = (asin(cosOfFaceVector) * 180 / Float.pi)
        
        pupilLine?.buildLineInTwoPointsWithRotation(from: faceAnchor.leftEyeTransform.position(), to: faceAnchor.rightEyeTransform.position(), radius: 0.0004, diffuse: UIColor.white)
        zPositionDiff = CGFloat(abs(faceAnchor.leftEyeTransform.position().z - faceAnchor.rightEyeTransform.position().z)) * 1000
    }
}

extension matrix_float4x4 {
    func position() -> SCNVector3 {
        return SCNVector3(columns.3.x, columns.3.y, columns.3.z)
    }
}
