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
    private static let borderColor = UIColor(red:0, green:0, blue:0, alpha:0.8)
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
        scene.rootNode.addChildNode(self.board)
    }
    
    private func createBoard() {
        let width = self.size.width
        let height = self.size.height
        
        for i in 1...2 {
            addLine(to: self.board, 0.001, Float(height), 0.001, Float(i), 0, 0)
        }
        for i in 1...2 {
            addLine(to: self.board, Float(width), 0.001, 0.001, 0, Float(i), 0)
        }
    }
    
    private func addLine(to node: SCNNode, _ w: Float, _ h: Float, _ l: Float, _ x: Float, _ y: Float, _ z: Float) {
        let line = SCNBox(width: cg(w), height: cg(h), length: cg(l), chamferRadius: 0)
        var translate = SCNMatrix4MakeTranslation(h / 3 * (x - 1.5), w / 3 * (y - 1.5), 0)
        translate = SCNMatrix4Translate(translate, 0, 0, 0)
        var transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1.0, 0.0, 0.0)
        transform = SCNMatrix4Rotate(transform, self.orientation, 0, 1, 0)
        let matrix = SCNMatrix4Translate(transform, 0, 0, 0)
        node.addChildNode(createNode(line, SCNMatrix4Mult(translate, matrix), SudokuScene.borderColor))
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
    
    private func translate(_ x: Float, _ y: Float, _ z: Float = 0) -> SCNMatrix4 {
        return SCNMatrix4MakeTranslation(self.x, self.y, self.z)
    }
    
    private func cg(_ f: Float) -> CGFloat { return CGFloat(f) }
}
