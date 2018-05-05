//
//  SudokuScene.swift
//  sudoku-solver
//
//  Created by Patryk Scheffler on 5/5/18.
//  Copyright © 2018 Patryk Scheffler. All rights reserved.
//

import Foundation
import SceneKit

class SudokuScene {
    private static let borderColor = UIColor(red:0.4, green:0.4, blue:0.4, alpha:1)
    private static let lightBorderColor = UIColor(red:0.7, green:0.7, blue:0.7, alpha:1)
    private static let textColor = UIColor(red:0.30, green:0.85, blue:0.39, alpha:1.0)
    
    private let orientation: Float
    private let scene: SCNScene
    private let size: CGSize
    private let x: Float
    private let y: Float
    private let z: Float
    
    private var board: SCNNode!
    
    init(_ scene: SCNScene, _ board: SCNNode, _ size: CGSize, _ orientation: Float, _ x: Float, _ y: Float, _ z: Float) {
        self.orientation = orientation
        self.scene = scene
        self.board = board
        self.size = size
        self.x = x
        self.y = y
        self.z = z
        
        createBoard()
        showBoard()
        scene.rootNode.addChildNode(self.board)
    }
    
    private func createBoard() {
        let width = self.size.width
        let height = self.size.height
        let length = max(width, height)
        
        for i in 0...9 {
            if i % 3 == 0 {
                addLine(to: self.board, 0.0005, Float(length), 0.001, Float(i), 0, Float(length / 9), 4.5, SudokuScene.borderColor)
            } else {
                addLine(to: self.board, 0.0001, Float(length), 0.0001, Float(i), 0, Float(length / 9), 4.5, SudokuScene.lightBorderColor)
            }
            
        }
        for i in 0...9 {
            if i % 3 == 0 {
                addLine(to: self.board, Float(length), 0.0005, 0.001, 0, Float(i), Float(length / 9), 4.5, SudokuScene.borderColor)
            } else {
                addLine(to: self.board, Float(length), 0.0001, 0.0001, 0, Float(i), Float(length / 9), 4.5, SudokuScene.lightBorderColor)
            }
        }
    }
    
    private func showBoard() {
        let width = self.size.width
        let height = self.size.height
        let length = max(width, height)
        
        addNumber(to: self.board, value: "1", 0, 0, Float(length / 9))
        addNumber(to: self.board, value: "2", 1, 1, Float(length / 9))
        addNumber(to: self.board, value: "3", 8, 8, Float(length / 9))
    }
    
    private func addNumber(to node: SCNNode, value: String, _ x: Float, _ y: Float, _ cell: Float) {
        var translate = SCNMatrix4MakeTranslation(cell * (x - 4.5), cell * (8 - y - 4.5), 0)
        translate = SCNMatrix4Translate(translate, cell / 5, 0, 0)
        let scale = SCNMatrix4Scale(translate, 0.0004, 0.0004, 0.0004)
        var transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1.0, 0.0, 0.0)
        transform = SCNMatrix4Rotate(transform, self.orientation, 0, 1, 0)
        transform = SCNMatrix4Rotate(transform, -Float.pi / 2.0, 0, 3, 0)
        let node = createNode(text(value), SCNMatrix4Mult(scale, transform), SudokuScene.textColor)
        animate(node, "opacity", from: 0, to: 1, during: 2)
        self.board.addChildNode(node)
    }
    
    private func addLine(to node: SCNNode, _ w: Float, _ h: Float, _ l: Float, _ x: Float, _ y: Float, _ cell: Float, _ padding: Float, _ color: UIColor) {
        let line = SCNBox(width: cg(w), height: cg(h), length: cg(l), chamferRadius: 0)
        var translate = SCNMatrix4MakeTranslation(cell * (x - padding), cell * (y - padding), 0)
        translate = SCNMatrix4Translate(translate, w / 2, h / 2, 0)
        var transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1.0, 0.0, 0.0)
        transform = SCNMatrix4Rotate(transform, self.orientation, 0, 1, 0)
        let matrix = SCNMatrix4Translate(transform, 0, 0, 0)
        
        node.addChildNode(createNode(line, SCNMatrix4Mult(translate, matrix), color))
    }
    
    private func createNode(_ geometry: SCNGeometry, _ matrix: SCNMatrix4, _ color: UIColor) -> SCNNode {
        let material = SCNMaterial()
        material.diffuse.contents = color
        // use the same material for all geometry elements
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry)
        node.transform = matrix
        
        return node
    }
    
    private func text(_ string: String) -> SCNText {
        let text = SCNText(string: string, extrusionDepth: 1)
        text.font = UIFont.systemFont(ofSize: 20)
        return text
    }
    
    private func animate(_ node: SCNNode, _ path: String, from: Any, to: Any, during: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: path)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = during
        animation.fillMode = kCAFillModeForwards
        animation.isRemovedOnCompletion = false
        node.addAnimation(animation, forKey: nil)
    }
    
    private func translate(_ x: Float, _ y: Float, _ z: Float = 0) -> SCNMatrix4 {
        return SCNMatrix4MakeTranslation(self.x, self.y, self.z)
    }
    
    private func cg(_ f: Float) -> CGFloat { return CGFloat(f) }
}
