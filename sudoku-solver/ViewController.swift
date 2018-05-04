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
    private var outlineLayers: [CAShapeLayer]?
    
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
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        if searchingForRectangles {
            findRectangle(frame: currentFrame)
        }
    }
    
    private func removeOutlines() {
        if let layers = self.outlineLayers {
            for layer in layers {
                layer.removeFromSuperlayer()
            }
            
            self.outlineLayers = nil
        }
    }
    
    private func findRectangle(frame currentFrame: ARFrame) {
        DispatchQueue.global(qos: .background).async {
            let request = VNDetectRectanglesRequest(completionHandler: { (request, error) in
                // Jump back onto the main thread
                DispatchQueue.main.async {
                    // self.searchingForRectangles = false
                    guard let observations = request.results as? [VNRectangleObservation],
                        let _ = observations.first else {
                            print("No results")
                            return
                    }
                    
                    print("\(observations.count) rectangles found")
                    
//                    if observations.count < 6 {
//                        return
//                    }
                    
                    if (self.outlineLayers != nil) {
                        self.removeOutlines()
                    }
                    
                    // Outline rectangles
                    var outlineLayers = [CAShapeLayer]()
                    
                    for rect in observations {
                        let points = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft]
                        let convertedPoints = points.map { self.sceneView.convertFromCamera($0) }
                        let outlineLayer = self.drawPolygon(convertedPoints, color: UIColor.red)
                        
                        outlineLayers.append(outlineLayer)
                        self.sceneView.layer.addSublayer(outlineLayer)
                    }
                    
                    self.outlineLayers = outlineLayers
                }
            })
            
            request.maximumObservations = 0
            
            // Perform request
            let handler = VNImageRequestHandler(cvPixelBuffer: currentFrame.capturedImage, options: [:])
            try? handler.perform([request])
        }
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

extension UIView {
    
    // Converts a point from camera coordinates (0 to 1 or -1 to 0, depending on orientation)
    // into a point within the given view
    func convertFromCamera(_ point: CGPoint) -> CGPoint {
        let orientation = UIApplication.shared.statusBarOrientation
        
        switch orientation {
        case .portrait, .unknown:
            return CGPoint(x: point.y * frame.width, y: point.x * frame.height)
        case .landscapeLeft:
            return CGPoint(x: (1 - point.x) * frame.width, y: point.y * frame.height)
        case .landscapeRight:
            return CGPoint(x: point.x * frame.width, y: (1 - point.y) * frame.height)
        case .portraitUpsideDown:
            return CGPoint(x: (1 - point.y) * frame.width, y: (1 - point.x) * frame.height)
        }
    }
    
    // Converts a rect from camera coordinates (0 to 1 or -1 to 0, depending on orientation)
    // into a point within the given view
    func convertFromCamera(_ rect: CGRect) -> CGRect {
        let orientation = UIApplication.shared.statusBarOrientation
        let x, y, w, h: CGFloat
        
        switch orientation {
        case .portrait, .unknown:
            w = rect.height
            h = rect.width
            x = rect.origin.y
            y = rect.origin.x
        case .landscapeLeft:
            w = rect.width
            h = rect.height
            x = 1 - rect.origin.x - w
            y = rect.origin.y
        case .landscapeRight:
            w = rect.width
            h = rect.height
            x = rect.origin.x
            y = 1 - rect.origin.y - h
        case .portraitUpsideDown:
            w = rect.height
            h = rect.width
            x = 1 - rect.origin.y - w
            y = 1 - rect.origin.x - h
        }
        
        return CGRect(x: x * frame.width, y: y * frame.height, width: w * frame.width, height: h * frame.height)
    }
    
}
