import Flutter
import UIKit
import GoogleMaps
import audioplayers_darwin

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Previene la eliminación de metadatos de Swift por optimización Whole Module en Release
    _ = AudioplayersDarwinPlugin.self

    GMSServices.provideAPIKey("AIzaSyCKB9H2-C7C2lbyyl1tp3R5rKoHyGosfII")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
