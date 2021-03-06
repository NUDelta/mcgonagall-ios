# McGonagall iOS

iOS component of the [McGonagall](https://github.com/NUDelta/mcgonagall) project. See that README for instructions as how  to setup the entire architecture.

## Requirements
Developed for > iOS 9.3.

## Usage
Enter in the sync code displayed on the [Wizard Control Center](http://rppt.meteorapp.com) to connect to the Meteor app and obtain a stream of the paper prototype. A stream of the iOS app screen will then be published to the Control Center and any gestures (tap + pan) will be overlaid on that stream. You can connect to another stream by resyncing.

## Structure Info

RPPTController
- Main user view.

RPPTPinViewController
- Where the user enter's the pin from the wizard's command center.

RPPTCameraViewController
- Custom camera controller implementation to support screen capture and 'AR'.

RPPTXXXFlowViewController
- Series of view controllers for basic app onboarding (getting permissions).

RPPTClient
- Communication infrastructure between wizard and user.

RPPTScreenCapturerIO
- Captures the screen using private APIs. Never submit this to the App Store.

## Contact
Meg Grasse at [meggrasse@u.northwestern.edu](mailto:meggrasse@u.northwestern.edu)  
