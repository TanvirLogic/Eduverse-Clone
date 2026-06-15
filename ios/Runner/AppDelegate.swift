import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "eduverse/video_metadata",
      binaryMessenger: engineBridge.pluginRegistry.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "getVideoInfo" {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARG", message: "path required", details: nil))
          return
        }

        let url: URL
        if path.hasPrefix("/") {
          url = URL(fileURLWithPath: path)
        } else {
          url = URL(string: path) ?? URL(fileURLWithPath: path)
        }

        let asset = AVAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        let durationSec = duration.isNaN ? 1 : Int(duration)

        var fileSize: Int64 = 0
        if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]) {
          fileSize = Int64(resourceValues.fileSize ?? 0)
        }

        result([
          "duration": durationSec,
          "fileSize": fileSize
        ])
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
