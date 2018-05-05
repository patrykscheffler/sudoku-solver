//
//  ViewController.swift
//  sudoku-solver
//
//  Created by Patryk Scheffler on 5/4/18.
//  Copyright © 2018 Patryk Scheffler. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    private var searchingForRectangles = true
    private var surfaceNodes = [ARPlaneAnchor:SurfaceNode]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        sceneView.session.delegate = self
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal

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
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        if searchingForRectangles {
            findRectangle(frame: currentFrame)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        let surface = SurfaceNode(anchor: anchor)
        surfaceNodes[anchor] = surface
        node.addChildNode(surface)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // See if this is a plane we are currently rendering
        guard let anchor = anchor as? ARPlaneAnchor,
            let surface = surfaceNodes[anchor] else {
                return
        }
        
        surface.update(anchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor,
            let surface = surfaceNodes[anchor] else {
                return
        }
        
        surface.removeFromParentNode()
        
        surfaceNodes.removeValue(forKey: anchor)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: sceneView)
            
            let hitList = sceneView.hitTest(location, options: nil)
            
            if let hitObject = hitList.first {
                let node = hitObject.node
                let parentNode = node.parent
                
                parentNode?.enumerateChildNodes { (childNode, stop) -> Void in
                    childNode.removeFromParentNode()
                }
                
                node.removeFromParentNode()
            }
            
        }
    }
    
    private func findRectangle(frame currentFrame: ARFrame) {
        DispatchQueue.global(qos: .background).async {
            let request = VNDetectRectanglesRequest(completionHandler: { (request, error) in
                // Jump back onto the main thread
                DispatchQueue.main.async {
                    guard let observations = request.results as? [VNRectangleObservation],
                        let _ = observations.first else {
                            // print("No results")
                            return
                    }
                    
                    if observations.count < 3 { return }
                    let isSudoku = self.checkSudoku(observations)
                    if !isSudoku { return }
                    guard let selectedRect = observations.first else {
                        return
                    }
                    
                    let centerX = selectedRect.topLeft.x + (selectedRect.bottomRight.x - selectedRect.topLeft.x) / 2
                    let centerY = selectedRect.topLeft.y + (selectedRect.bottomRight.y - selectedRect.topLeft.y) / 2
                    let centerPoint = CGPoint(x: centerX, y: centerY)
                    let hitList = self.sceneView.hitTest(self.sceneView.convertFromCamera(centerPoint), options: nil)
                    
                    if hitList.count == 0 {
                        self.addPlaneRect(for: selectedRect)
                    }
                }
            })
            
            request.maximumObservations = 0
            request.quadratureTolerance = 15
            request.minimumAspectRatio = 0.8
            
            // Perform request
            let handler = VNImageRequestHandler(cvPixelBuffer: currentFrame.capturedImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func checkSudoku(_ observations: [VNRectangleObservation]) -> Bool {
        guard let outerRect = observations.first else {
            return false
        }
        
        let outerHeight = abs(outerRect.topLeft.y - outerRect.bottomRight.y)
        let outerWidth = abs(outerRect.topLeft.x - outerRect.bottomRight.x)
        let croppedObservations = observations.dropFirst()
        var counter = 0
        
        for rect in croppedObservations {
            let height = abs(rect.topLeft.y - rect.bottomRight.y)
            let width = abs(rect.topLeft.x - rect.bottomRight.x)
            
            if height < (outerHeight / 3) && width < (outerWidth / 3) &&
                rect.topLeft.x > outerRect.topLeft.x &&
                rect.topLeft.y < outerRect.topLeft.y &&
                rect.bottomRight.x < outerRect.bottomRight.x &&
                rect.bottomRight.y > outerRect.bottomRight.y {
                counter += 1
            }
        }
        
        if counter > 2 {
            return true
        }
        
        return false
    }
    
    private func addPlaneRect(for observedRect: VNRectangleObservation) {
        // Convert to 3D coordinates
        guard let planeRectangle = PlaneRectangle(for: observedRect, in: sceneView) else {
            return
        }
        
        let boardNode = RectangleNode(planeRectangle)
        let x = boardNode.position.x
        let y = boardNode.position.y
        let z = boardNode.position.z
        
        let _ = SudokuScene(sceneView.scene, boardNode, planeRectangle.size, planeRectangle.orientation, x, y, z)
    }
    
    private func drawPolygon(_ points: [CGPoint], color: UIColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let path = UIBezierPath()
        
        layer.fillColor = nil
        layer.strokeColor = color.cgColor
        layer.lineWidth = 2
        
        path.move(to: points.last!)
        points.forEach { point in
            path.addLine(to: point)
        }
        
        layer.path = path.cgPath
        
        return layer
    }
}
