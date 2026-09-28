import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let downloadBookmarkKey = "downloadDirectoryBookmark"

  /// The user-picked download folder we currently hold sandbox access to.
  private var scopedDownloadURL: URL?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "musehub/system",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "revealPath":
        self.revealPath(call.arguments, result: result)
      case "pickDirectory":
        self.pickDirectory(result: result)
      case "restoreDirectory":
        result(self.restoreDirectory())
      case "clearDirectory":
        self.releaseScopedDirectory()
        UserDefaults.standard.removeObject(forKey: MainFlutterWindow.downloadBookmarkKey)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  // Revealing the downloads folder in Finder.
  //
  // The app runs inside the macOS App Sandbox, which denies spawning
  // /usr/bin/open, so Dart's Process.run("open", ...) silently fails and
  // the "open download folder" button did nothing. NSWorkspace is the
  // sandbox-approved way to do this.
  private func revealPath(_ arguments: Any?, result: FlutterResult) {
    guard let path = (arguments as? [String: Any])?["path"] as? String,
          !path.isEmpty
    else {
      result(false)
      return
    }
    result(NSWorkspace.shared.open(URL(fileURLWithPath: path)))
  }

  // Choosing a download folder.
  //
  // A sandboxed app may only write outside its container to a folder the
  // user picked in the system panel, and that grant dies with the process.
  // A security-scoped bookmark is what carries it across launches, so the
  // pick is saved as one and resolved again on every start.
  private func pickDirectory(result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.beginSheetModal(for: self) { [weak self] response in
      guard let self = self, response == .OK, let url = panel.url else {
        result(nil)
        return
      }
      do {
        let bookmark = try url.bookmarkData(
          options: .withSecurityScope,
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: MainFlutterWindow.downloadBookmarkKey)
        self.adoptScopedDirectory(url)
        result(url.path)
      } catch {
        result(FlutterError(
          code: "bookmark_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
  }

  private func restoreDirectory() -> String? {
    guard let bookmark = UserDefaults.standard.data(
      forKey: MainFlutterWindow.downloadBookmarkKey
    ) else {
      return nil
    }
    var stale = false
    guard let url = try? URL(
      resolvingBookmarkData: bookmark,
      options: .withSecurityScope,
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    ) else {
      return nil
    }
    guard adoptScopedDirectory(url) else { return nil }
    if stale, let refreshed = try? url.bookmarkData(
      options: .withSecurityScope,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    ) {
      UserDefaults.standard.set(refreshed, forKey: MainFlutterWindow.downloadBookmarkKey)
    }
    return url.path
  }

  @discardableResult
  private func adoptScopedDirectory(_ url: URL) -> Bool {
    releaseScopedDirectory()
    guard url.startAccessingSecurityScopedResource() else { return false }
    scopedDownloadURL = url
    return true
  }

  private func releaseScopedDirectory() {
    scopedDownloadURL?.stopAccessingSecurityScopedResource()
    scopedDownloadURL = nil
  }
}
