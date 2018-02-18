//
//  RPPTPinViewController.swift
//  RRPTPin
//
//  Created by Andrew Finke on 12/10/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import UIKit
import ReplayKit

class RPPTPinViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    // MARK: - Properties

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.text = "Scan QR Code"
        label.font = UIFont.systemFont(ofSize: 40.0, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.white
        return label
    }()

    private let connectButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)

        button.setTitle("Retry", for: .normal)
        button.setTitleColor(.white, for: .normal)

        button.backgroundColor = #colorLiteral(red: 0.2745098039, green: 0.6274509804, blue: 0.9019607843, alpha: 1)

        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                                      AVMetadataObject.ObjectType.code39,
                                      AVMetadataObject.ObjectType.code39Mod43,
                                      AVMetadataObject.ObjectType.code93,
                                      AVMetadataObject.ObjectType.code128,
                                      AVMetadataObject.ObjectType.ean8,
                                      AVMetadataObject.ObjectType.ean13,
                                      AVMetadataObject.ObjectType.aztec,
                                      AVMetadataObject.ObjectType.pdf417,
                                      AVMetadataObject.ObjectType.itf14,
                                      AVMetadataObject.ObjectType.dataMatrix,
                                      AVMetadataObject.ObjectType.interleaved2of5,
                                      AVMetadataObject.ObjectType.qr]

    private var capturedURL = false
    private var inSetup = false

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        connectButton.alpha = 0.0
        connectButton.addTarget(self, action: #selector(retryButtonPressed), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(connectButton)

        let constraints = [
            titleLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            titleLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            titleLabel.heightAnchor.constraint(equalToConstant: 100),

            connectButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            connectButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
            connectButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            connectButton.heightAnchor.constraint(equalToConstant: 50)
        ]
        NSLayoutConstraint.activate(constraints)

        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.tintColor = .purple
        navigationController?.view.backgroundColor = .clear

        RPScreenRecorder.shared().startCapture(handler: { (_, _, _) in
            RPScreenRecorder.shared().stopCapture(handler: nil)
        }, completionHandler: nil)

        if UserDefaults.standard.bool(forKey: "SetupComplete") {
            configureSession()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession.stopRunning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !UserDefaults.standard.bool(forKey: "SetupComplete") {
            inSetup = true
        } else if inSetup {
            inSetup = false
            configureSession()
        } else {
            captureSession.startRunning()
        }
        capturedURL = false
        titleLabel.text = "Scan QR Code"
        connectButton.alpha = 0.0
        RPPTClient.shared?.disconnect()
        RPPTClient.shared = nil
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !UserDefaults.standard.bool(forKey: "SetupComplete") {
            let flowNav = UINavigationController(rootViewController: RPPTInitalFlowViewController())
            navigationController?.present(flowNav, animated: false, completion: nil)
        }
    }

    // MARK: - AVSession

    func configureSession() {
        // Get the back-facing camera for capturing videos
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera],
                                                                      mediaType: AVMediaType.video,
                                                                      position: .back)

        guard let captureDevice = deviceDiscoverySession.devices.first else {
            fatalError()
        }

        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)

            // Set the input device on the capture session.
            captureSession.addInput(input)

            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)

            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes

        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }

        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer?.frame = view.layer.bounds
        view.layer.insertSublayer(previewLayer!, at: 0)

        // Start video capture.
        captureSession.startRunning()
    }

    @objc
    func retryButtonPressed() {
        titleLabel.text = "Scan QR Code"
        UIView.animate(withDuration: 0.5, animations: {
            self.connectButton.alpha = 0.0
        })
        capturedURL = false
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {

        guard !capturedURL,
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            supportedCodeTypes.contains(object.type),
            let objectString = object.stringValue as NSString?,
            objectString.contains("?"),
            URL(string: objectString as String) != nil else {
                return
        }

        capturedURL = true

        let range = objectString.range(of: "?")
        let endPoint = objectString.substring(to: range.location)
        let pin = objectString.substring(from: range.location + 1)

        titleLabel.text = "Connecting"

        RPPTClient.shared = RPPTClient(endpoint: endPoint, ready: {
            self.performSegue(withIdentifier: "connect", sender: pin)
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIView.animate(withDuration: 0.25, animations: {
                self.connectButton.alpha = 1.0
            })
        }

        RPPTClient.shared?.connectWebSocket()
    }

    // MARK: - Segue

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let syncCode = sender as? String,
            let destination = segue.destination as? RPPTController else {
            fatalError()
        }
        destination.syncCode = syncCode
    }

}
