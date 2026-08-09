import Flutter
import UIKit
import GoogleMaps
import camera_avfoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCKB9H2-C7C2lbyyl1tp3R5rKoHyGosfII")

    // Retain CameraPlugin Swift class metadata to prevent swift_getObjectType launch crash
    _ = CameraPlugin.self

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
