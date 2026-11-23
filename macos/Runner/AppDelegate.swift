import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Files Finder asked us to open ("Open With", double-click, drop on the
  // Dock icon). They wait here until Dart asks for them ("takePending"),
  // then go out as they arrive.
  private var pendingFiles: [String] = []
  private var dartListening = false
  private var openChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Called by MainFlutterWindow once its engine exists.
  func attachOpenChannel(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "svga_gallery/open", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, call.method == "takePending" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.dartListening = true
      result(self.pendingFiles)
      self.pendingFiles.removeAll()
    }
    openChannel = channel
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    let files = urls.filter(\.isFileURL).map(\.path)
    let others = urls.filter { !$0.isFileURL }
    if !others.isEmpty {
      super.application(application, open: others)
    }
    guard !files.isEmpty else { return }
    if dartListening, let openChannel {
      openChannel.invokeMethod("open", arguments: files)
    } else {
      pendingFiles.append(contentsOf: files)
    }
  }
}
