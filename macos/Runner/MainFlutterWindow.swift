import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Revealing the downloads folder in Finder.
    //
    // The app runs inside the macOS App Sandbox, which denies spawning
    // /usr/bin/open, so Dart's Process.run("open", ...) silently fails and
    // the "open download folder" button did nothing. NSWorkspace is the
    // sandbox-approved way to do this, and the folder lives inside our own
    // container, so no extra entitlement is required.
    let channel = FlutterMethodChannel(
      name: "musehub/system",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "revealPath" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let path = (call.arguments as? [String: Any])?["path"] as? String,
            !path.isEmpty
      else {
        result(false)
        return
      }
      let opened = NSWorkspace.shared.open(URL(fileURLWithPath: path))
      result(opened)
    }

    super.awakeFromNib()
  }
}
