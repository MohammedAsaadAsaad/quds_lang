import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let desiredFrame = NSRect(x: 0, y: 0, width: 1120, height: 740)
    self.contentViewController = flutterViewController
    self.title = "Quds Installer"
    self.minSize = NSSize(width: 900, height: 620)
    self.setFrame(desiredFrame, display: true)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
