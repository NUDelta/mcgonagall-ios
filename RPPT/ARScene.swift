//
//  ARScene.swift
//  ARMoji
//
//  Created by Andrew Finke on 1/13/18.
//  Copyright © 2018 Andrew Finke. All rights reserved.
//

import SpriteKit
import ARKit

class ARScene: SKScene {

    func addAnchor() {
        guard let sceneView = self.view as? ARSKView else {
            return
        }

        // Create anchor using the camera's current position
        if let currentFrame = sceneView.session.currentFrame {

            // Create a transform with a translation of 0.2 meters in front of the camera
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -0.2
            let transform = simd_mul(currentFrame.camera.transform, translation)

            // Add a new anchor to the session
            let anchor = ARAnchor(transform: transform)
            sceneView.session.add(anchor: anchor)
        }
    }
}
