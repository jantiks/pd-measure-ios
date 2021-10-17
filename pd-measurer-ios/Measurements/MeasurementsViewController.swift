//
//  PDMeasurementViewController.swift
//  pd-measurer-ios
//
//  Created by Tigran Arsenyan on 10/2/21.
//

import UIKit
import ARKit
import SceneKit
import MessageUI

class MeasurementsViewController: UIViewController {
    
    @IBOutlet private weak var sceneView: ARSCNView!
    @IBOutlet private weak var shImageView: UIImageView!
    @IBOutlet private weak var resultView: UIView!
    @IBOutlet private weak var farPdLabel: UILabel!
    @IBOutlet private weak var nearPdLabel: UILabel!
    @IBOutlet private weak var loaderView: UIActivityIndicatorView!
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var shButton: UIButton!
    @IBOutlet private weak var leftButtons: UIView!
    @IBOutlet private weak var rightButtons: UIView!
    @IBOutlet private weak var applyButton: UIButton!
    
    private var email: Email?
    private var measurementType: MeasurementType = .pd
    private var lastSnapshot: UIImage?
    private var leftSHLayer = CAShapeLayer()
    private var rightSHLayer = CAShapeLayer()
    private var pupilLine: SCNNode? = nil
    private var zPositionDiff: CGFloat = 0
    private var blendShapes: [ARFaceAnchor.BlendShapeLocation : NSNumber] = [:]
    private var faceAngle: Float = 0
    private var scanTimer: Timer?
    private var deleteResultsTimer: Timer?
    private var pixelInMm: CGFloat = 0
    private var pdResults: [CGFloat] = []
    private var isFirstMeasurement = true
    private var leftPupilPoint: CGPoint?
    private var rightPupilPoint: CGPoint?
    private var nosePoint: CGPoint?
    private var leftSHChange: CGFloat = 0.0
    private var rightSHChnage: CGFloat = 0.0
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startTracking()
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        initTimers()
        initUi()
        startLoader()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        stopTracking()
    }
    
    func setEmail(_ email: Email) {
        self.email = email
    }
    
    private func startLoader() {
        [farPdLabel, nearPdLabel].forEach({ $0?.isHidden = true })
        loaderView.startAnimating()
    }
    
    private func stopLoader() {
        [farPdLabel, nearPdLabel].forEach({ $0?.isHidden = false })
        loaderView.stopAnimating()
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
    
    private func initTimers() {
        scanTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(scanForFaces), userInfo: nil, repeats: true)
        deleteResultsTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(deleteResults), userInfo: nil, repeats: true)
    }
    
    private func initUi() {
        view.layer.addSublayer(leftSHLayer)
        view.layer.addSublayer(rightSHLayer)
        
        resultView.layer.cornerRadius = 10
        resultView.alpha = 0.7
        shButton.layer.cornerRadius = 10
        applyButton.layer.cornerRadius = 10
        leftButtons.layer.cornerRadius = 10
        rightButtons.layer.cornerRadius = 10
        
        loaderView.hidesWhenStopped = true
        [shButton, applyButton, shImageView, leftButtons, rightButtons].forEach({ $0?.isHidden = true })
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
        if pdResults.count >= 5 {
            stopLoader()
            pdResults.removeFirst()
            if measurementType == .pd {
                shButton.isHidden = false
                applyButton.isHidden = false
            }
        }
    }
    
    @objc private func scanForPresentedController() {
        if presentedViewController == nil, measurementType == .pd {
            startTracking()
            initTimers()
        } else {
            Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(scanForPresentedController), userInfo: nil, repeats: false)
        }
    }
    
    @objc
    private func scanForFaces() {
        guard shouldScanFace() else { return }
        guard measurementType == .pd else { return }
        //get the captured image of the ARSession's current frame
        pupilLine?.isHidden = true
        let capturedImage = sceneView.snapshot()
        pupilLine?.isHidden = false
        
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
                
                self.lastSnapshot = capturedImage
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
        
        if let leftLandmark = face.landmarks?.leftPupil, let leftNormalizedPoint = leftLandmark.normalizedPoints.first,
           let rightLandmark = face.landmarks?.rightPupil, let rightNormalizedPoint = rightLandmark.normalizedPoints.first,
           let nosePointNormalized = face.landmarks?.nose?.normalizedPoints[1] {
            // draw the face rect
            let affineTransform = CGAffineTransform(translationX: 0, y: size.height)
                .scaledBy(x: 1.0, y: -1.0)

            // draw the face rect
            let w = face.boundingBox.size.width * size.width
            let h = face.boundingBox.size.height * size.height
            let x = face.boundingBox.origin.x * size.width
            let y = face.boundingBox.origin.y * size.height

            leftPupilPoint = CGPoint(x: x + CGFloat(leftNormalizedPoint.x) * w, y: y + CGFloat(leftNormalizedPoint.y) * h).applying(affineTransform)
            rightPupilPoint = CGPoint(x: x + CGFloat(rightNormalizedPoint.x) * w, y: y + CGFloat(rightNormalizedPoint.y) * h).applying(affineTransform)
            nosePoint = CGPoint(x: x + CGFloat(nosePointNormalized.x) * w, y: y + CGFloat(nosePointNormalized.y) * h).applying(affineTransform)
            
            pdResults.append(((SCNHelper.CGPointDistance(from: leftPupilPoint!, to: rightPupilPoint!)) * pixelInMm) + zPositionDiff)
            
            updateResultLables(getAveragePdResult(), getAveragePdResult() - 3)
        }
    }
    
    private func getAveragePdResult() -> CGFloat {
        guard pdResults.count > 0 else { return 0 }
        
        var averageResult: CGFloat = 0
        pdResults.forEach({ averageResult += CGFloat($0) })
        
        return averageResult / CGFloat(pdResults.count)
    }
    
    private func updateResultLables(_ first: CGFloat?, _ second: CGFloat?) {
        if measurementType == .pd {
            farPdLabel.text = "Far PD: \(String(format: "%.01f", first ?? "N/A"))"
            nearPdLabel.text = "Near PD: \(String(format: "%.01f", second ?? "N/A"))"
        } else {
            farPdLabel.text = "Left SH: \(String(format: "%.01f", first ?? "N/A"))"
            nearPdLabel.text = "Right SH: \(String(format: "%.01f", second ?? "N/A"))"
        }
    }
    
    private func removeNodes() {
        print("worked remove nodes")
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
    
    private func stopTracking() {
        sceneView.session.pause()
        scanTimer?.invalidate()
        deleteResultsTimer?.invalidate()
    }
    
    private func showSHLayers() {
        guard let leftPupilPoint = leftPupilPoint, let rightPupilPoint = rightPupilPoint, let nosePoint = nosePoint  else { return }

        // left sh layer
        let leftPath = CGMutablePath()
        leftPath.addLines(between: [CGPoint(x: leftPupilPoint.x - 10, y: leftPupilPoint.y), CGPoint(x: leftPupilPoint.x + 10, y: leftPupilPoint.y)])
        leftPath.addLines(between: [leftPupilPoint, CGPoint(x: leftPupilPoint.x, y: nosePoint.y + leftSHChange)])
        leftPath.addLines(between: [CGPoint(x: leftPupilPoint.x - 10, y: nosePoint.y + leftSHChange), CGPoint(x: leftPupilPoint.x + 10, y: nosePoint.y + leftSHChange)])
        
        leftSHLayer.path = leftPath
        leftSHLayer.strokeColor = UIColor.white.cgColor
        leftSHLayer.lineWidth = 1.5
        leftSHLayer.opacity = 1
        
        // right sh layer
        let rightPath = CGMutablePath()
        rightPath.addLines(between: [CGPoint(x: rightPupilPoint.x - 10, y: rightPupilPoint.y), CGPoint(x: rightPupilPoint.x + 10, y: rightPupilPoint.y)])
        rightPath.addLines(between: [rightPupilPoint, CGPoint(x: rightPupilPoint.x, y: nosePoint.y + rightSHChnage)])
        rightPath.addLines(between: [CGPoint(x: rightPupilPoint.x - 10, y: nosePoint.y + rightSHChnage), CGPoint(x: rightPupilPoint.x + 10, y: nosePoint.y + rightSHChnage)])
        
        rightSHLayer.path = rightPath
        rightSHLayer.strokeColor = UIColor.white.cgColor
        rightSHLayer.lineWidth = 1.5
        rightSHLayer.opacity = 1
    }
    
    private func getLeftSH() -> CGFloat? {
        if measurementType == .pd {
            return nil
        }
        
        return (nosePoint!.y - leftPupilPoint!.y + leftSHChange) * pixelInMm
    }
    
    private func getRightSH() -> CGFloat? {
        if measurementType == .pd {
            return nil
        }
        
        return (nosePoint!.y  - rightPupilPoint!.y + rightSHChnage) * pixelInMm
    }
    
    private func getEmailBody() -> String? {
        return email?.getEmailBody()
    }
    
    private func reset() {
        pdResults = []
        isFirstMeasurement = true
        [shImageView, shButton ,leftButtons, rightButtons, applyButton].forEach({ $0?.isHidden = true })
        pupilLine?.isHidden = true
        measurementType = .pd
        
        leftSHLayer.path = nil
        rightSHLayer.path = nil
        leftSHChange = 0
        rightSHChnage = 0
        
        startTracking()
        startLoader()
    }
    
    @IBAction private func closeAction(_ sender: UIButton) {
        stopTracking()
        dismiss(animated: true)
    }
    
    @IBAction func resetAction(_ sender: UIButton) {
        reset()
    }
    
    @IBAction func shMeasureAction(_ sender: UIButton) {
        measurementType = .sh
        
        stopTracking()
        
        shImageView.image = lastSnapshot
        [shImageView, leftButtons, rightButtons, applyButton].forEach({ $0?.isHidden = false })
        removeNodes()
        shButton.isHidden = true
        showSHLayers()
        updateResultLables(getLeftSH(), getRightSH())
    }
    
    @IBAction func applyAction(_ sender: UIButton) {
        stopTracking()
        
        email?.setFarPD(Float(getAveragePdResult()))
        email?.setNearPD(Float(getAveragePdResult() - 3))
        getLeftSH() == nil ? email?.setLeftSH(nil) : email?.setLeftSH(Float(getLeftSH()!))
        getRightSH() == nil ? email?.setRightSH(nil) : email?.setRightSH(Float(getRightSH()!))
        
        let ac = UIActivityViewController(activityItems: [email?.getEmailBody() as Any], applicationActivities: nil)
        present(ac, animated: true)
        
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(scanForPresentedController), userInfo: nil, repeats: false)
    }
    
    @IBAction func leftUpAction(_ sender: UIButton) {
        let changePixels: CGFloat = 0.3 / pixelInMm
        leftSHChange -= changePixels
        showSHLayers()
        updateResultLables(getLeftSH(), getRightSH())
    }
    
    @IBAction func leftDownAction(_ sender: UIButton) {
        let changePixels: CGFloat = 0.3 / pixelInMm
        leftSHChange += changePixels
        showSHLayers()
        updateResultLables(getLeftSH(), getRightSH())
    }
    
    @IBAction func rightUpAction(_ sender: UIButton) {
        let changePixels: CGFloat = 0.3 / pixelInMm
        rightSHChnage -= changePixels
        showSHLayers()
        updateResultLables(getLeftSH(), getRightSH())
    }
    
    @IBAction func rightDownAction(_ sender: UIButton) {
        let changePixels: CGFloat = 0.3 / pixelInMm
        rightSHChnage += changePixels
        showSHLayers()
        updateResultLables(getLeftSH(), getRightSH())
    }
}

extension MeasurementsViewController: ARSCNViewDelegate, ARSessionDelegate {
    
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
        print("WORKED RENDERE NODES")

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
        
        pixelInMm = CGFloat((pixelInMm1 + pixelInMm2 + pixelInMm3 + pixelInMm4)) / CGFloat(4)

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
