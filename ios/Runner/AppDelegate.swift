import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCKB9H2-C7C2lbyyl1tp3R5rKoHyGosfII")

    if window == nil {
      let flutterViewController = FlutterViewController(project: nil, initialRoute: nil, nibName: nil, bundle: nil)
      window = UIWindow(frame: UIScreen.main.bounds)
      window?.rootViewController = flutterViewController
      window?.makeKeyAndVisible()
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
