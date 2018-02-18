//
//  RPPTController.swift
//  RPPT
//
//  Created by Kevin Chen on 10/3/14.
//  Copyright (c) 2014 aspin. All rights reserved.
//

import UIKit
import MapKit
import MobileCoreServices

class RPPTController: UIViewController {

    var syncCode: String!
    var viewHasAppeared = false

    // MARK: - Interface Elements

    let activityView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)

    let mapView = MKMapView()

    let textView = UITextView()
    let imageView = UIImageView()
    let overlayedImageView = UIImageView()

    var picker: UIImagePickerController?

    // MARK: - Properties

    var task: RPPTTask? {
        didSet {
            if let task = task {
                title = task.content
                AudioServicesPlaySystemSound(1003)
            }
        }
    }

    var touchDelay: Timer?
    var canSendTouches = true

    let client = RPPTClient.shared

    var lastPoint: CGPoint = .zero

    var photoArray = [UIImage]()
    var keyboardViewLabel: UILabel?


    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Connecting"

        textView.returnKeyType = .send
        textView.delegate = self
        textView.backgroundColor = .clear

        setupClient()

        activityView.center = view.center
        activityView.color = .darkGray
        activityView.startAnimating()
        view.addSubview(activityView)

        activityView.alpha = 0.0
        navigationController?.navigationBar.alpha = 0.0
        UIApplication.shared.isNetworkActivityIndicatorVisible = true

        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardDidShow, object: nil, queue: nil) { [weak self] notification in
            guard let userInfo = notification.userInfo else {return}

            if let myData = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect {
                DispatchQueue.main.async {
                    let tempView = UILabel(frame: myData)
                    tempView.backgroundColor = UIColor.darkGray
                    tempView.text = "User Keyboard Active"
                    tempView.textAlignment = .center
                    tempView.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
                    tempView.textColor = UIColor.white

                    self?.keyboardViewLabel = tempView
                    self?.view.addSubview(tempView)
                }
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardDidHide, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async {
                self?.keyboardViewLabel?.removeFromSuperview()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !viewHasAppeared {
            viewHasAppeared = true
            client?.start(withSyncCode: syncCode, safeAreaY: view.safeAreaInsets.top)
            UIView.animate(withDuration: 0.5) {
                self.activityView.alpha = 1.0
                self.navigationController?.navigationBar.alpha = 1.0
            }
        }
    }

    // MARK: - Setup

    private func setupClient() {
        client?.onTaskUpdated = { [weak self] task in
            self?.task = task
        }

        client?.onLocationUpdated = { [weak self] location in
            let mapSpan = MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            let mapCoordinateRegion = MKCoordinateRegion(center: location, span: mapSpan)
            self?.mapView.region = mapCoordinateRegion
        }

        client?.onClientError = { error in
            print(error)
        }

        client?.onOpenTokError = { [weak self] error in
            print(error)
            if let controller = self?.presentedViewController {
                controller.dismiss(animated: true, completion: {
                    self?.presentAlert(title: "Sync Issue",
                                      message: "There was an issue syncing with the wizard. Please try again.")
                })
            } else {
                self?.presentAlert(title: "Sync Issue",
                                  message: "There was an issue syncing with the wizard. Please try again.")
            }
        }

        client?.onSubscriberConnected = { [weak self] subscriberView in
            guard let view = self?.view else { return }

            UINotificationFeedbackGenerator().notificationOccurred(.success)

            subscriberView.translatesAutoresizingMaskIntoConstraints = false
//            subscriberView.transform = CGAffineTransform(scaleX: -1, y: 1)
            self?.view.addSubview(subscriberView)

            let constraints = [
                subscriberView.leftAnchor.constraint(equalTo: view.leftAnchor),
                subscriberView.rightAnchor.constraint(equalTo: view.rightAnchor),
                subscriberView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                subscriberView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ]
            NSLayoutConstraint.activate(constraints)

            self?.title = "Connected"
            UIView.animate(withDuration: 0.5, animations: {
                self?.activityView.alpha = 0.0
            }, completion: { _ in
                self?.activityView.removeFromSuperview()
            })

            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(messageChanged),
                                               name: NSNotification.Name("messages_changed"),
                                               object: nil)
    }

    // MARK: - Helpers

    func presentAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "Ok", style: .cancel) { _ in
            self.navigationController?.popToRootViewController(animated: true)
        }
        alertController.addAction(action)
        present(alertController, animated: true, completion: nil)

        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // MARK: - Comms

    // TODO: THIS
    @objc func messageChanged(notification: NSNotification) {
        guard let result = notification.userInfo as? [String:String] else { return }

        if result["type"] == "task",
            let taskID = result["_id"],
            taskID == task?.messageID,
            let content = result["content"] {
            self.task = RPPTTask(content: content, messageID: taskID)
        }

        // temp hijacking
        if result["keyboard"] == "show" {
            // Where do these numbers come from
            textView.frame = CGRect(x: 50, y: self.view.frame.height - 256, width: self.view.frame.width - 10, height: 40)
            self.view.addSubview(textView)
            self.textView.becomeFirstResponder()



        } else if result["keyboard"] == "hide" {
            self.textView.resignFirstResponder()
            self.textView.removeFromSuperview()
        }

        if result["camera"] == "show" {
            if picker == nil {
                picker = UIImagePickerController()
                picker?.sourceType = .camera
                picker?.mediaTypes = [kUTTypeImage as String]
                picker?.delegate = self

                if let picker = picker {
                    present(picker, animated: true, completion: nil)
                }
            }
        } else if result["camera"] == "hide" {
            if picker != nil {
                picker?.dismiss(animated: true, completion: nil)
                picker = nil
            }
        }

        if let imageFullEncoding = result["overlayedFullImage"] {
            self.overlayFullImage(imageEncoding: imageFullEncoding)
        }

        if let overlayedImageXString = result["overlayedImage_x"],
            let overlayedImageYString = result["overlayedImage_y"],
            let overlayedImageHeightString = result["overlayedImage_height"],
            let overlayedImageWidthString = result["overlayedImage_width"],
            let imageEncoding = result["overlayedImage"] {

            let overlayedImageX = Double(overlayedImageXString)
            let overlayedImageY = Double(overlayedImageYString)
            let overlayedImageHeight = Double(overlayedImageHeightString)
            let overlayedImageWidth = Double(overlayedImageWidthString)
            let isCameraOverlay = (result["isCameraOverlay"] == "true") ? true : false

            if overlayedImageX != -999 &&
                overlayedImageY != -999 &&
                overlayedImageWidth != -999 &&
                overlayedImageHeight != -999 {

                self.overlayImage(x: CGFloat(overlayedImageX!),
                                  y: CGFloat(overlayedImageY!),
                                  height: CGFloat(overlayedImageHeight!),
                                  width: CGFloat(overlayedImageWidth!),
                                  imageEncoding: imageEncoding,
                                  isCameraOverlay: isCameraOverlay)
            } else {
                self.overlayedImageView.removeFromSuperview()
            }
        }

        if let mapXString = result["map_x"],
            let mapYString = result["map_y"],
            let mapWidthString = result["map_width"],
            let mapHeightString = result["map_height"] {

            let mapX = Double(mapXString)
            let mapY = Double(mapYString)
            let mapHeight = Double(mapHeightString)
            let mapWidth = Double(mapWidthString)
            if mapX != -999 && mapY != -999 && mapWidth != -999 && mapHeight != -999 {

                mapView.frame = CGRect(x: CGFloat(mapX!),
                                       y: CGFloat(mapY!),
                                       width: CGFloat(mapWidth!),
                                       height: CGFloat(mapHeight!))

                if overlayedImageView.isDescendant(of: self.view) {
                    self.view.insertSubview(mapView, belowSubview: overlayedImageView)
                } else {
                    self.view.addSubview(mapView)
                }
            } else {
                self.mapView.removeFromSuperview()
            }
        }

        if let photoXString = result["photo_x"],
            let photoYString = result["photo_y"],
            let photoWidthString = result["photo_width"],
            let photoHeightString = result["photo_height"] {

            let photoX = Double(photoXString)
            let photoY = Double(photoYString)
            let photoHeight = Double(photoHeightString)
            let photoWidth = Double(photoWidthString)

            if photoX != -999 && photoY != -999 && photoWidth != -999 && photoHeight != -999 {
                if !photoArray.isEmpty {
                    imageView.frame = CGRect(x: CGFloat(photoX!), y: CGFloat(photoY!), width: CGFloat(photoWidth!), height: CGFloat(photoHeight!))
                    imageView.image = photoArray.last!
                    if overlayedImageView.isDescendant(of: self.view) {
                        self.view.insertSubview(imageView, belowSubview: overlayedImageView)
                    } else {
                        self.view.addSubview(imageView)
                    }
                }
            } else {
                self.imageView.removeFromSuperview()
            }
        }
    }

    func overlayFullImage(imageEncoding: String) {
        let dataDecoded = Data(base64Encoded: imageEncoding, options: .ignoreUnknownCharacters)
        let decodedimage = UIImage(data: dataDecoded!)
//        overlayedImageView.frame = (subscriber.view?.frame)!
        overlayedImageView.image = decodedimage
        self.view.addSubview(overlayedImageView)
        self.view.bringSubview(toFront: overlayedImageView)
    }

    // TODO: Fix
    //swiftlint:disable:next identifier_name
    func overlayImage(x: CGFloat, y: CGFloat, height: CGFloat, width: CGFloat, imageEncoding: String, isCameraOverlay: Bool) {
        let dataDecoded = Data(base64Encoded: imageEncoding, options: .ignoreUnknownCharacters)
        let decodedimage = UIImage(data: dataDecoded!)
        overlayedImageView.image = decodedimage
        overlayedImageView.frame = CGRect(x: x, y: y, width: width, height: height)
        if (isCameraOverlay) {
            picker?.showsCameraControls = false
            picker?.cameraOverlayView = overlayedImageView
        } else {
            self.view.addSubview(overlayedImageView)
            self.view.bringSubview(toFront: overlayedImageView)
        }
    }

    func resetStreams() {
        //To fix
        // TODO: I GUESS FIX??
//        if let sess = subscribingSession {
//            var error : OTError? = nil
//            sess.disconnect(&error)
//            subscriber.view?.removeFromSuperview()
//
//        }
    }

    // MARK: - User Interactions

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        let taps = touches.flatMap({ $0.location(in: view) })
        sendTaps(points: taps)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        let taps = touches.flatMap({ $0.location(in: view) })
        sendTaps(points: taps)
    }

    // TODO: Fix
    //swiftlint:disable:next identifier_name
    func sendTaps(points: [CGPoint]) {

        guard canSendTouches else {
            return
        }

        canSendTouches = false
        for point in points {
            client?.createTap(scaledX: point.x, scaledY: point.y)
        }

        touchDelay = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false, block: { _ in
            self.canSendTouches = true
        })
    }

}

extension RPPTController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - UIImagePickerController Delegate

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            fatalError("Failed to get image from image picker.")
        }
        photoArray.append(image)
        picker.dismiss(animated: true, completion: nil)
    }
}

extension RPPTController: UITextViewDelegate {

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        guard textView.text.last == "\n" else { return }
        client?.sendMessage(text: textView.text)
        textView.text = ""
    }
}
