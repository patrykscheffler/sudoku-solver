//
//  SurfaceNode.swift
//  sudoku-solver
//
//  Created by Patryk Scheffler on 5/4/18.
//  Copyright © 2018 Patryk Scheffler. All rights reserved.
//

import ARKit

class SurfaceNode: SCNNode {
    var anchor: ARPlaneAnchor!
    var planeGeometry: SCNPlane!
    
    init(anchor: ARPlaneAnchor) {
        super.init()
        
        // Create the 3D plane geometry with the dimensions reported
        // by ARKit in the ARPlaneAnchor instance
        self.anchor = anchor
        self.planeGeometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ anchor: ARPlaneAnchor) {
        self.planeGeometry.width = CGFloat(anchor.extent.x)
        self.planeGeometry.height = CGFloat(anchor.extent.z)
        
        // When the plane is first created it's center is 0,0,0 and
        // the nodes transform contains the translation parameters.
        // As the plane is updated the planes translation remains the
        // same but it's center is updated so we need to update the 3D
        // geometry position
        self.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z);
    }
}
