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
import CoreML

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    private var searchingForRectangles = true
    private var surfaceNodes = [ARPlaneAnchor:SurfaceNode]()
    let model = numbers()
    
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
                            return
                    }
                    
                    if observations.count < 3 { return }
                    let isSudoku = self.checkSudoku(observations)
                    if !isSudoku { return }
                    guard let selectedRect = observations.first else {
                        return
                    }
                    
                    if (abs(selectedRect.topLeft.y - selectedRect.topRight.y) > 0.02) ||
                        (abs(selectedRect.bottomLeft.y - selectedRect.bottomRight.y) > 0.02) ||
                        (abs(selectedRect.topLeft.x - selectedRect.bottomLeft.x) > 0.02) ||
                        (abs(selectedRect.topRight.x - selectedRect.bottomRight.x) > 0.02) {
                        return
                    }
                    
                    let centerX = selectedRect.topLeft.x + (selectedRect.bottomRight.x - selectedRect.topLeft.x) / 2
                    let centerY = selectedRect.topLeft.y + (selectedRect.bottomRight.y - selectedRect.topLeft.y) / 2
                    let centerPoint = CGPoint(x: centerX, y: centerY)
                    let hitList = self.sceneView.hitTest(self.sceneView.convertFromCamera(centerPoint), options: nil)
                    
                    if hitList.count == 0 {
                        let image = self.convertToUIImage(pixelBuffer: currentFrame.capturedImage, frame: currentFrame)

                        let width = abs(selectedRect.topRight.y - selectedRect.bottomLeft.y) * image.size.width / 9
                        let height = abs(selectedRect.topRight.x - selectedRect.bottomLeft.x) * image.size.height / 9
                        let offset = max(width, height) / 10
                        
                        var sudokuOriginal : [[Int64?]] = Array(repeating: Array(repeating: -1, count: 9), count: 9)
                        var sudoku: Sudoku = Array(repeating: Array(repeating: -1, count: 9), count: 9)
                        
                        let startX = selectedRect.bottomLeft.y * image.size.width
                        let startY = selectedRect.bottomLeft.x * image.size.height
                        
                        guard let planeRectangle = PlaneRectangle(for: selectedRect, in: self.sceneView) else {
                            return
                        }
                        
                        let boardNode = RectangleNode(planeRectangle)
                        let x = boardNode.position.x
                        let y = boardNode.position.y
                        let z = boardNode.position.z
                        
                        for i in 0...8 {
                            for j in 0...8 {
                                let boundingBox = CGRect(x: startX + (width - offset / 3.2) * CGFloat(i) + offset, y: startY + (height - offset / 2) * CGFloat(j) + offset, width: width, height: height)
                                let croppedCGImage:CGImage = (image.cgImage?.cropping(to: boundingBox))!
                                let croppedImage = UIImage(cgImage: croppedCGImage).noir
                                
                                let filter = ThresholdFilter()
                                filter.inputImage = CIImage(image: croppedImage!, options: [kCIImageColorSpace: NSNull()])
                                let thresholdImage = UIImage(ciImage: filter.outputImage)
                                
                                let resizedImage = thresholdImage.resize(to: CGSize(width: 28, height: 28))
                                let pixelBuffer = resizedImage?.pixelBuffer()
                                let output = try? self.model.prediction(image: pixelBuffer!)
                                
                                if let _value = output?.output1[(output?.classLabel)!] {
                                    if (_value > 0.95) {
                                        sudokuOriginal[i][j] = output?.classLabel
                                        sudoku[i][j] = Square(integerLiteral: Int(sudokuOriginal[i][j] ?? 0))
                                        
                                    } else {
                                        sudoku[i][j] = -1
                                        sudokuOriginal[i][j] = -1
                                    }
                                } else {
                                    sudoku[i][j] = -1
                                    sudokuOriginal[i][j] = -1
                                }
                            }
                        }
                        
                        let newSudoku : Sudoku = sudoku
                        if let sudokuSolution = solveSudoku(s: newSudoku) {
                            let _ = SudokuScene(self.sceneView.scene, boardNode, planeRectangle.size, planeRectangle.orientation, x, y, z, sudokuOriginal, sudokuSolution)
                        } else {
                            let _ = SudokuScene(self.sceneView.scene, boardNode, planeRectangle.size, planeRectangle.orientation, x, y, z, sudokuOriginal, sudoku)
                        }
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
    
    func convertToUIImage(pixelBuffer: CVPixelBuffer, frame: ARFrame) -> UIImage {
        let orient = UIApplication.shared.statusBarOrientation
        let viewportSize = self.sceneView.bounds.size
        let transform = frame.displayTransform(for: orient, viewportSize: viewportSize).inverted()
        let finalImage = CIImage(cvPixelBuffer: pixelBuffer).transformed(by: transform)
        
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(finalImage, from: finalImage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        
        return image
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
    
    private func addPlaneRect(for observedRect: VNRectangleObservation) -> RectangleNode? {
        // Convert to 3D coordinates
        guard let planeRectangle = PlaneRectangle(for: observedRect, in: sceneView) else {
            return nil
        }
        
        let boardNode = RectangleNode(planeRectangle)
        
        return boardNode
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

extension UIImage {
    func applying(contrast value: NSNumber) -> UIImage? {
        guard
            let ciImage = CIImage(image: self)?.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: value])
            else { return nil } // Swift 3 uses withInputParameters instead of parameters
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        UIImage(ciImage: ciImage).draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    var invert: UIImage? {
        let context = CIContext(options: nil)
        guard let currentFilter = CIFilter(name: "CIColorInvert") else { return nil }
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        if let output = currentFilter.outputImage,
            let cgImage = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        }
        return nil
    }
    
    var noir: UIImage? {
        let context = CIContext(options: nil)
        guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else { return nil }
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        if let output = currentFilter.outputImage,
            let cgImage = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        }
        return nil
    }
    
    func resize(to newSize: CGSize) -> UIImage? {
        guard self.size != newSize else { return self }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        
        defer { UIGraphicsEndImageContext() }
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func pixelBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
    func pixelBuffer2() -> CVPixelBuffer? {
                var pixelBuffer: CVPixelBuffer? = nil
        
                let width = Int(self.size.width)
                let height = Int(self.size.height)
        
                CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent8, nil, &pixelBuffer)
                CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue:0))
 
               let colorspace = CGColorSpaceCreateDeviceGray()
                let bitmapContext = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer!), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: colorspace, bitmapInfo: 0)!

        
              guard let cg = self.cgImage else {
                    return nil
                   }
                bitmapContext.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixelBuffer
    }
}

class ThresholdFilter: CIFilter
{
    var inputImage : CIImage?
    // var threshold: Float = 0.554688 // This is set to a good value via Otsu's method
    var threshold: Float = 0.4
    
    var thresholdKernel =  CIColorKernel(source:
        "kernel vec4 thresholdKernel(sampler image, float threshold) {" +
            "  vec4 pixel = sample(image, samplerCoord(image));" +
            "  const vec3 rgbToIntensity = vec3(0.114, 0.587, 0.299);" +
            "  float intensity = dot(pixel.rgb, rgbToIntensity);" +
            "  return intensity < threshold ? vec4(0, 0, 0, 1) : vec4(1, 1, 1, 1);" +
        "}")
    
    override var outputImage: CIImage! {
        guard let inputImage = inputImage,
            let thresholdKernel = thresholdKernel else {
                return nil
        }
        
        let extent = inputImage.extent
        let arguments : [Any] = [inputImage, threshold]
        return thresholdKernel.apply(extent: extent, arguments: arguments)
    }
}
