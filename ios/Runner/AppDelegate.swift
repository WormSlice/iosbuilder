import Flutter
import UIKit
import GoogleMaps
import camera_avfoundation
import app_links
import sign_in_with_apple
import record_ios
import speech_to_text
import geolocator_apple
import geocoding_ios

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCKB9H2-C7C2lbyyl1tp3R5rKoHyGosfII")

    // Registrar plugins de Swift directamente en Swift con metadatos de clase validos
    if let r = self.registrar(forPlugin: "AppLinksIosPlugin") { AppLinksIosPlugin.register(with: r) }
    if let r = self.registrar(forPlugin: "CameraPlugin") { CameraPlugin.register(with: r) }
    if let r = self.registrar(forPlugin: "SignInWithApplePlugin") { SignInWithApplePlugin.register(with: r) }
    if let r = self.registrar(forPlugin: "RecordIosPlugin") { RecordIosPlugin.register(with: r) }
    if let r = self.registrar(forPlugin: "SpeechToTextPlugin") { SpeechToTextPlugin.register(with: r) }
    if let r = self.registrar(forPlugin: "GeolocatorPlugin") { GeolocatorPlugin.register(with: r) }
    if let r = self.registrar(forPlugin: "GeocodingPlugin") { GeocodingPlugin.register(with: r) }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
