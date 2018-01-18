//
//  RPPTCameraFlowViewController.swift
//  RPPTFlow
//
//  Created by Andrew Finke on 12/10/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import UIKit
import AVFoundation

class RPPTCameraFlowViewController: RPPTFlowViewController {

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        titleText = "Camera Access"
        descriptionText = "McGonagall needs camera access for the camera module."
        continueText = "Enable"

        let placeholderLabel = UILabel()
        placeholderLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        placeholderLabel.text = "Picture of wizard looking at camera."
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(placeholderLabel)

        let constraints = [
            placeholderLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            placeholderLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            placeholderLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
    }

    override func continueButtonPressed() {
        let title = "Camera Access Required"
        let message = "Camera access  is required to setup McGonagall. Please open settings to enable camera access."
        AVCaptureDevice.requestAccess(for: .video) { success in
            DispatchQueue.main.async {
                if success {
                    let flowVC = RPPTMicFlowViewController()
                    self.navigationController?.pushViewController(flowVC, animated: true)
                } else {
                    self.presentAlert(title: title, message: message)
                }
            }

        }
    }

}
