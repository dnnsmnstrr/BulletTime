//
//  ViewController.swift
//  BulletTime
//
//  Created by Dennis Muensterer on 01.06.18.
//  Copyright © 2018 Dennis Muensterer. All rights reserved.
//

import UIKit
import SceneKit
import ARKit


class ViewController: UIViewController, UIGestureRecognizerDelegate, ARSCNViewDelegate, ARSessionDelegate {
    
    //MARK: Internal Properties
    
    var circleNode: SCNNode!
    var images: [UIImage] = []
    
    
    //MARK: Outlets

    @IBOutlet weak var connectionsLabel: UILabel!
    @IBOutlet weak var sendMapButton: UIBarButtonItem!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var verticalSlider: UISlider!{
        didSet{
            verticalSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi)/2)

        }
    }
    @IBAction func changeRadius(_ sender: Any) {
        setCircleRadius(radius: verticalSlider.value)
        connectionManager.sendRadius(radius: verticalSlider.value)
    }
    @IBAction func resetTrackingButton(_ sender: Any) {
        resetTracking()
    }
    // MARK: - UI Elements
    
//    var focusSquare = FocusSquare()
    let connectionManager = ConnectionManager()
    
    var circle: SCNTorus?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCameraButton()
                
        // Set the delegates
        sceneView.delegate = self
        connectionManager.delegate = self
        
        // Prevent the screen from being dimmed after a while
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Show statistics such as fps and timing information and f
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, SCNDebugOptions.showConstraints, SCNDebugOptions.showLightExtents, ARSCNDebugOptions.showWorldOrigin]
        
        // Create a new scene
        let scene = SCNScene()
        circle = SCNTorus(ringRadius: 0.1, pipeRadius: 0.03)
        circleNode = SCNNode(geometry: circle)
        scene.rootNode.addChildNode(circleNode)
        // Set the scene to the view
        sceneView.scene = scene
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        
        self.sceneView.autoenablesDefaultLighting = true
        
        
    }
    /// - Tag: PlaceARContent
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Place content only for anchors found by plane detection.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

        // Create a SceneKit plane to visualize the plane anchor using its position and extent.
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)

        // `SCNPlane` is vertically oriented in its local coordinate space, so
        // rotate the plane to match the horizontal orientation of `ARPlaneAnchor`.
        planeNode.eulerAngles.x = -.pi / 2

        // Make the plane visualization semitransparent to clearly show real-world placement.
        planeNode.opacity = 0

        // Add the plane visualization to the ARKit-managed node so that it tracks
        // changes in the plane anchor as plane estimation continues.
        node.addChildNode(planeNode)
    }

    /// - Tag: UpdateARContent
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update content only for plane anchors and nodes matching the setup created in `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }

        // Plane estimation may shift the center of a plane relative to its anchor's transform.
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)

        // Plane estimation may also extend planes, or remove one plane to merge its extent into another.
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
    }

    
    func cameraPicker() {
        if UIImagePickerController.isSourceTypeAvailable(.camera){
            let myPickerController = UIImagePickerController()
            myPickerController.delegate = self as? UIImagePickerControllerDelegate & UINavigationControllerDelegate;
            myPickerController.sourceType = .camera
            self.present(myPickerController, animated: true, completion: nil)
        }
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage else { return }
        
        dismiss(animated: true)
        
        connectionManager.send(image: image)
//        images.append(image)
        
        print(images.count)
        
        
    }
    
    func setupCameraButton() {
        
        cameraButton.backgroundColor = .white
        cameraButton.layer.borderColor = UIColor.black.cgColor
        cameraButton.layer.borderWidth = 2
        cameraButton.layer.cornerRadius = min(cameraButton.frame.width, cameraButton.frame.height) / 2
        
        cameraButton.addTarget(self, action: #selector(buttonAction), for: UIControl.Event.touchUpInside)
        
    }
    
    @objc func buttonAction() {
        cameraPicker()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    
    // MARK: - Session tracking methods
    
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        
        switch camera.trackingState {
        case .notAvailable, .limited: break
        //            self.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
        case .normal: break
            //            statusViewController.cancelScheduledMessage(for: .trackingStateEscalation)
            //
            //            // Unhide content after successful relocalization.
            //            virtualObjectLoader.loadedObjects.forEach { $0.isHidden = false }
        }
    }
    
    /// - Tag: CheckMappingStatus
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if #available(iOS 12.0, *) {
            switch frame.worldMappingStatus {
            case .notAvailable, .limited:
                sendMapButton.isEnabled = false
            case .extending:
                sendMapButton.isEnabled = !connectionManager.session.connectedPeers.isEmpty
            case .mapped:
                sendMapButton.isEnabled = !connectionManager.session.connectedPeers.isEmpty
            }
        } else {
            // Fallback on earlier versions
            sendMapButton.isEnabled = false
        }
//        mappingStatusLabel.text = frame.worldMappingStatus.description
//        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
    }
    
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Hide content before going into the background.
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        /*
         Allow the session to attempt to resume after an interruption.
         This process may not succeed, so the app must be prepared
         to reset the session if the relocalizing status continues
         for a long time -- see `escalateFeedback` in `StatusViewController`.
         */
        return true
    }
    
    
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    


    @IBAction func shareSession(_ sender: Any) {
        if #available(iOS 12.0, *) {
            sceneView.session.getCurrentWorldMap { worldMap, error in
                guard let map = worldMap
                    else { print("Error: \(error!.localizedDescription)"); return }
                guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                    else { fatalError("can't encode map") }
                self.connectionManager.sendToAllPeers(data)
            }
        } else {
            // Fallback on earlier versions
            
        }
    }
        
    // MARK: - Selecting planes and adding circle.
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            print("Unable to identify touches on any plane. Ignoring interaction...")
            return
        }
        
        let result = sceneView.hitTest(touch.location(in: sceneView), types: [ARHitTestResult.ResultType.featurePoint, ARHitTestResult.ResultType.estimatedHorizontalPlane])
        guard let hitResult = result.last else {return}
        let hitTransform = SCNMatrix4(hitResult.worldTransform)
        let hitVector = SCNVector3Make(hitTransform.m41, hitTransform.m42, hitTransform.m43)
        positionCircle(position: hitVector)
        
//        // Send the position info to peers, so they can place the same content.
//        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: hitVector, requiringSecureCoding: true)
//            else { fatalError("can't encode new Position") }
//        self.connectionManager.sendToAllPeers(data)


        if #available(iOS 12.0, *) {
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: hitVector, requiringSecureCoding: true)
                else { fatalError("can't encode new Position") }
            self.connectionManager.sendToAllPeers(data)
            
//            let anchor = ARAnchor(name: "circle", transform: hitResult.worldTransform)
//            sceneView.session.add(anchor: anchor)
//
//            // Send the anchor info to peers, so they can place the same content.
//            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
//                else { fatalError("can't encode anchor") }
//            self.connectionManager.sendToAllPeers(data)

        } else {
            // Fallback on earlier versions

            // Send the position info to peers, so they can place the same content.
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: hitVector, requiringSecureCoding: true)
                else { fatalError("can't encode new Position") }
            self.connectionManager.sendToAllPeers(data)

        }
        
    }


    func positionCircle(position: SCNVector3) {
        circleNode.position = position
    }
    
    func setCircleRadius(radius: Float) {
        circle?.ringRadius = CGFloat(radius)
        circleNode.geometry = circle
    }
    
    
    func addCircleToPlane(plane: VirtualPlane, atPoint point: CGPoint) {
        let hits = sceneView.hitTest(point, types: .existingPlaneUsingExtent)
        if hits.count > 0, let firstHit = hits.first {
            if let newCircle = circleNode?.clone() {
                newCircle.position = SCNVector3Make(firstHit.worldTransform.columns.3.x, firstHit.worldTransform.columns.3.y, firstHit.worldTransform.columns.3.z)
                cleanupARSession()
                sceneView.scene.rootNode.addChildNode(newCircle)
            }
        }
    }
    
    func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func cleanupARSession() {
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) -> Void in
            node.removeFromParentNode()
        }
    }
    
}

extension ViewController : ConnectionManagerDelegate {
    
    func receivedRadius(manager: ConnectionManager, radius: Float) {
        setCircleRadius(radius: radius)
        OperationQueue.main.addOperation {
            self.verticalSlider.value = radius
        }
    }
    
    func receivedImage(manager: ConnectionManager, image: UIImage) {
        images.append(image)
    }
    
    /// - Tag: ReceiveWorld
    func receivedData(_ data: Data) {
        if #available(iOS 12.0, *) {
            if let unarchived = try? NSKeyedUnarchiver.unarchivedObject(of: ARWorldMap.classForKeyedUnarchiver(), from: data),
                let worldMap = unarchived as? ARWorldMap {
                
                // Run the session with the received world map.
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = .horizontal
                configuration.initialWorldMap = worldMap
                sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                
                // Remember who provided the map for showing UI feedback.
//                mapProvider = peer
            }
            else
                if let unarchived = try? NSKeyedUnarchiver.unarchivedObject(of: ARAnchor.classForKeyedUnarchiver(), from: data),
                    let anchor = unarchived as? ARAnchor {
                    
                    sceneView.session.add(anchor: anchor)
            }
            else
                if let unarchived = NSKeyedUnarchiver.unarchiveObject(with: data),
                    let position = unarchived as? SCNVector3{
                    print("repositioning")
                    positionCircle(position: position)
            }
            else {
                  print("weird data received")
            }
        }
            
        else {
            // Fallback on earlier versions
            if let unarchived = NSKeyedUnarchiver.unarchiveObject(with: data),
                let position = unarchived as? SCNVector3{
                print("repositioning")
                positionCircle(position: position)
            }
            else{
                print("Error! Not on iOS 12, or didn't receive position")

            }
        }
    }
    
    func connectedDevicesChanged(manager: ConnectionManager, connectedDevices: [String]) {
        OperationQueue.main.addOperation {
            self.connectionsLabel.text = "Connections: \(connectedDevices)"
        }
    }
}

//
//extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate{
//    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//        self.dismiss(animated: true, completion: nil)
//    }
//
//    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
//        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
//            self.imagePickedBlock?(image)
//            print("Picture taken: \(image)")
//        }else{
//            print("Something went wrong")
//        }
//        self.dismiss(animated: true, completion: nil)
//    }
//
//}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
