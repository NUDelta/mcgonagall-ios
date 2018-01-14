//
//  ARViewController.swift
//  ARMoji
//
//  Created by Andrew Finke on 1/13/18.
//  Copyright © 2018 Andrew Finke. All rights reserved.
//

import UIKit
import SpriteKit
import ARKit

class ARViewController: UIViewController, ARSKViewDelegate {

    @IBOutlet private var sceneView: ARSKView!
    private var taskToAdd: RPPTTask?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view's delegate
        sceneView.delegate = self

        // Show statistics such as fps and node count
        sceneView.showsFPS = true
        sceneView.showsNodeCount = true

        let scene = ARScene()
        scene.size = CGSize(width: 750, height: 750)
        sceneView.presentScene(scene)
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

    func addTask(task: RPPTTask) {
        taskToAdd = task
        (sceneView.scene as? ARScene)?.addAnchor()
    }

    // MARK: - ARSKViewDelegate

    func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? {
        guard let task = taskToAdd else { return nil }

        let labelNode = SKLabelNode(text: task.content)
        // One font to rule them all
        labelNode.fontName = UIFont.systemFont(ofSize: 10).fontName
        labelNode.fontSize = 10
        labelNode.horizontalAlignmentMode = .center
        labelNode.verticalAlignmentMode = .center
        return labelNode
    }

}
