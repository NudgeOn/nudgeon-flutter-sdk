import Flutter
import UIKit
import NudgeOnSDK

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let qa = FlutterMethodChannel(name: "io.nudgeon/qa", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    qa.setMethodCallHandler { call, result in
      if call.method == "emit", let args = call.arguments as? [String: String], let id = args["id"] {
        let payload: [AnyHashable: Any] = ["aps": ["alert": ["title":"Fixture", "body":"Synthetic callback"]], "nudgeon": ["message_id":id]]
        result(args["event"] == "opened" ? NudgeOn.handlePushOpened(payload) : NudgeOn.handlePushReceived(payload))
      } else if call.method == "result", let value = call.arguments as? String {
        let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("bridge-result.json")
        try? value.write(to: file, atomically: true, encoding: .utf8)
        NSLog("NUDGEON_BRIDGE_QA %@", value)
        result(nil)
      } else { result(FlutterMethodNotImplemented) }
    }
  }
}
