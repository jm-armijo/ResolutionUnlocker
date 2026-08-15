//
//  ResolutionUnlocker
//
//  Created by @waydabber
//

import Cocoa
import os.log
import ServiceManagement
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
  var isSleep: Bool = false
  var reconfigureID: Int = 0
  var skipReconfiguration = false
  let updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: UpdaterDelegate(), userDriverDelegate: nil)
  let menu = AppMenu()

  // MARK: *** Setup app

  func applicationDidFinishLaunching(_: Notification) {
    // When this executable is only hosting the XCTest bundle, skip the full menu-bar boot.
    // Otherwise the host app would restore prefs and connect a stored virtual display mid-test,
    // making the real main display report as virtual and breaking the CoreDisplay
    // characterization tests. Guard runs before `app = self` so global `app` stays nil in tests.
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      return
    }
    app = self
    VirtualDisplayManager.updateDefinitions()
    self.menu.setupMenu()
    VirtualDisplayManager.menuRefresher = self.menu
    self.setDefaultPrefs()
    VirtualDisplayManager.restoreFromPrefs()
    // Update checking is intentionally not started: no appcast/SUFeedURL is published yet,
    // so starting the updater would surface an "Unable to check for updates" error. The
    // Sparkle updater is left wired up (dormant) so it can be re-enabled once updates ship.
    self.displayReconfiguration(force: true)

    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.sleepNotification), name: NSWorkspace.screensDidSleepNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.sleepNotification), name: NSWorkspace.willSleepNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.wakeNotification), name: NSWorkspace.screensDidWakeNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.wakeNotification), name: NSWorkspace.didWakeNotification, object: nil)
    CGDisplayRegisterReconfigurationCallback({ _, _, _ in app.displayReconfiguration() }, nil)
  }

  func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "\(Branding.appName) is already running!"
    if prefs.bool(forKey: PrefKey.hideMenuIcon.rawValue) || self.menu.statusBarItem.isVisible == false {
      self.menu.statusBarItem.isVisible = true
      prefs.set(true, forKey: PrefKey.hideMenuIcon.rawValue)
      VirtualDisplayManager.storeToPrefs()
      self.menu.populateSettingsMenu()
      alert.informativeText = "The menu icon was hidden but it is now set to visible. You can hide it again in Settings."
    } else {
      alert.informativeText = "To configure the app, use the \(Branding.appName) menu icon in the macOS menu bar!"
    }
    alert.runModal()
    return true
  }

  func setDefaultPrefs() {
    if !prefs.bool(forKey: PrefKey.appAlreadyLaunched.rawValue) {
      prefs.set(true, forKey: PrefKey.appAlreadyLaunched.rawValue)
      prefs.set(false, forKey: PrefKey.SUEnableAutomaticChecks.rawValue)
      os_log("Setting default preferences.", type: .info)
    }
    prefs.set(Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1") ?? 1, forKey: PrefKey.buildNumber.rawValue)
  }

  func getStartAtLogin() -> Bool {
    (SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]])?.first { $0["Label"] as? String == "\(Bundle.main.bundleIdentifier!)Helper" }?["OnDemand"] as? Bool ?? false
  }

  // MARK: *** Handlers - Specific virtual display management

  @objc func createVirtualDisplay(_ sender: AnyObject?) {
    if let menuItem = sender as? NSMenuItem {
      os_log("Connecting virtual display tagged in new menu as %{public}@", type: .info, "\(menuItem.tag)")
      if let number = VirtualDisplayManager.createByDefinitionId(menuItem.tag) {
        self.menu.populateAppMenu()
        VirtualDisplayManager.storeToPrefs()
        if let virtualDisplay = VirtualDisplayManager.getByNumber(number), virtualDisplay.isConnected {
          os_log("Virtual display successfully created and connected.", type: .info)
        } else {
          os_log("There seems to be a problem with the created virtual display.", type: .info)
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Your new \(Branding.displayNoun.lowercased()) was created and connected."
        alert.informativeText = "Use Displays under System Preferences to configure your new \(Branding.displayNoun.lowercased())! You can use the app menu to change its settings."
        alert.runModal()
      } else {
        os_log("Could not create virtual display using menu item tag number.", type: .info)
      }
    }
  }

  @objc func connectDisconnectVirtualDisplay(_ sender: AnyObject?) {
    if let menuItem = sender as? NSMenuItem, let virtualDisplay = VirtualDisplayManager.getByNumber(menuItem.tag) {
      if !virtualDisplay.isConnected {
        os_log("Connecting virtual display tagged in menu as %{public}@", type: .info, "\(menuItem.tag)")
        if virtualDisplay.hasAssociatedDisplay() {
          let alert = NSAlert()
          alert.alertStyle = .warning
          alert.messageText = "This \(Branding.displayNoun.lowercased()) cannot be manually connected!"
          alert.informativeText = "A \(Branding.displayNoun.lowercased()) which is associated with a display will connect automatically when the associated display is connected."
          alert.runModal()
        } else {
          if !virtualDisplay.connect() {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Unable to connect \(Branding.displayNoun.lowercased())"
            alert.informativeText = "An error occured during connecting the \(Branding.displayNoun.lowercased())."
            alert.runModal()
          }
        }
      } else {
        os_log("Disconnecting virtual display tagged in menu as %{public}@", type: .info, "\(menuItem.tag)")
        if virtualDisplay.hasAssociatedDisplay() {
          let alert = NSAlert()
          alert.alertStyle = .warning
          alert.messageText = "This \(Branding.displayNoun.lowercased()) cannot be manually disconnected!"
          alert.informativeText = "A \(Branding.displayNoun.lowercased()) which is associated with a display will disconnect automatically when the associated display is disconnected."
          alert.runModal()
        } else {
          virtualDisplay.disconnect()
        }
      }
      self.menu.populateAppMenu()
      VirtualDisplayManager.storeToPrefs()
      app.menu.appMenu.cancelTrackingWithoutAnimation()
    }
  }

  @objc func discardVirtualDisplay(_ sender: AnyObject?) {
    if let menuItem = sender as? NSMenuItem {
      let alert = NSAlert()
      alert.alertStyle = .critical
      alert.messageText = "Do you want to discard the \(Branding.displayNoun.lowercased())?"
      alert.informativeText = "If you would like to use a \(Branding.displayNoun.lowercased()) later, use disconnect instead so macOS display configuration data is preserved."
      alert.addButton(withTitle: "Cancel")
      alert.addButton(withTitle: "Discard")
      if alert.runModal() == .alertSecondButtonReturn {
        os_log("Removing virtual display tagged in manage menu as %{public}@", type: .info, "\(menuItem.tag)")
        VirtualDisplayManager.discardByNumber(menuItem.tag)
        self.menu.populateAppMenu()
        VirtualDisplayManager.storeToPrefs()
      }
    }
  }

  @objc func lowResolution(_ sender: AnyObject?) {
    if let menuItem = sender as? NSMenuItem, let virtualDisplay = VirtualDisplayManager.getByNumber(menuItem.tag), let display = DisplayManager.getDisplayById(virtualDisplay.displayIdentifier) {
      let resolutions = display.resolutions
      var previousWidth: UInt32 = 0
      var matchingResolutionKey: Int32 = -1
      for resolution in resolutions.sorted(by: { $0.0 < $1.0 }) where resolution.value.height >= 720 && resolution.value.hiDPI == !display.isHiDPI && resolution.value.width > previousWidth {
        previousWidth = resolution.value.width
        if resolution.value.width > display.width {
          break
        }
        matchingResolutionKey = Int32(resolution.key)
      }
      if matchingResolutionKey != -1 {
        display.changeResolution(resolutionItemNumber: matchingResolutionKey)
        self.displayReconfiguration(force: true)
      }
    }
  }

  @objc func associateVirtualDisplay(_ sender: NSMenuItem) {
    os_log("Received association request from tag %{public}@", type: .info, "\(sender.tag)")
    guard sender.tag != 0 else {
      return
    }
    let displayNumber = (sender.tag >> 8) & 0xFF
    let number = sender.tag & 0xFF
    if let virtualDisplay = VirtualDisplayManager.getByNumber(number), let display = DisplayManager.getDisplayByNumber(displayNumber) {
      virtualDisplay.associateDisplay(display: display)
      var askedForPermission = false
      for otherVirtualDisplay in VirtualDisplayManager.getAll() where otherVirtualDisplay != virtualDisplay {
        if otherVirtualDisplay.hasAssociatedDisplay(), otherVirtualDisplay.associatedDisplayPrefsId == virtualDisplay.associatedDisplayPrefsId {
          if askedForPermission {
            otherVirtualDisplay.disassociateDisplay()
          } else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Disassociate and disconnect other associated \(Branding.displayNounPlural.lowercased())?"
            alert.informativeText = "At least one other \(Branding.displayNoun.lowercased()) is associated with this display. To avoid confusion, it is best to avoid this situation."
            alert.addButton(withTitle: "Disassociate")
            alert.addButton(withTitle: "No")
            if alert.runModal() == .alertFirstButtonReturn {
              otherVirtualDisplay.disassociateDisplay()
              otherVirtualDisplay.disconnect()
              askedForPermission = true
            } else {
              break
            }
          }
        }
      }
      if !virtualDisplay.isConnected, DisplayManager.getDisplayByPrefsId(virtualDisplay.associatedDisplayPrefsId) != nil {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "This \(Branding.displayNoun.lowercased()) will now be connected."
        alert.informativeText = "The \(Branding.displayNoun.lowercased()) is now associated with a display that is connected therefore the \(Branding.displayNoun.lowercased()) will automtically connect."
        alert.runModal()
        _ = virtualDisplay.connect()
      }
      self.menu.populateAppMenu()
      VirtualDisplayManager.storeToPrefs()
    }
    _ = sender.tag
  }

  @objc func disassociateVirtualDisplay(_ sender: NSMenuItem) {
    if let virtualDisplay = VirtualDisplayManager.getByNumber(sender.tag), virtualDisplay.hasAssociatedDisplay() {
      let associatedDisplayPrefsId = virtualDisplay.associatedDisplayPrefsId
      virtualDisplay.disassociateDisplay()
      if virtualDisplay.isConnected, DisplayManager.getDisplayByPrefsId(associatedDisplayPrefsId) != nil {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Do you want to disconnect the \(Branding.displayNoun.lowercased()) as well?"
        alert.informativeText = "The \(Branding.displayNoun.lowercased()) is now disassociated from a display but the \(Branding.displayNoun.lowercased()) is still connected."
        alert.addButton(withTitle: "Disconnect")
        alert.addButton(withTitle: "No")
        if alert.runModal() == .alertFirstButtonReturn {
          virtualDisplay.disconnect()
        }
      }
      self.menu.populateAppMenu()
      VirtualDisplayManager.storeToPrefs()
    }
  }

  @objc func virtualDisplayResolution(_ sender: NSMenuItem) {
    os_log("Received resolution change from tag %{public}@", type: .info, "\(sender.tag)")
    guard sender.tag != 0 else {
      return
    }
    let number = (sender.tag >> 16) & 0xFFFF
    let resolutionItemNumber = sender.tag & 0xFFFF
    os_log("- Resolution change virtual display %{public}@", type: .info, "\(number)")
    os_log("- Resolution change item %{public}@", type: .info, "\(resolutionItemNumber)")
    if let virtualDisplay = VirtualDisplayManager.getByNumber(number), let display = DisplayManager.getDisplayById(virtualDisplay.displayIdentifier) {
      display.changeResolution(resolutionItemNumber: Int32(resolutionItemNumber))
      self.menu.populateAppMenu()
    }
  }

  // MARK: *** Handlers - General virtual display management

  @objc func connectAllVirtualDisplays(_: AnyObject?) {
    os_log("Connecting all virtual displays.", type: .info)
    var hasAssociated = false
    for virtualDisplay in VirtualDisplayManager.getAll() where !virtualDisplay.isConnected {
      if !virtualDisplay.hasAssociatedDisplay() {
        _ = virtualDisplay.connect()
      } else {
        hasAssociated = true
      }
    }
    if hasAssociated {
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "\(Branding.displayNounPlural) associated with displays cannot be manually connected!"
      alert.informativeText = "A \(Branding.displayNoun.lowercased()) which is associated with a display will automatically connect when the associated display is connected. All other \(Branding.displayNounPlural.lowercased()) were connected."
      alert.runModal()
    }
    self.menu.populateAppMenu()
    VirtualDisplayManager.storeToPrefs()
  }

  @objc func disconnectAllVirtualDisplays(_: AnyObject?) {
    os_log("Disconnecting all virtual displays.", type: .info)
    var hasAssociated = false
    for virtualDisplay in VirtualDisplayManager.getAll() where virtualDisplay.isConnected {
      if !virtualDisplay.hasAssociatedDisplay() {
        virtualDisplay.disconnect()
      } else {
        hasAssociated = true
      }
    }
    if hasAssociated {
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "\(Branding.displayNounPlural) associated with displays cannot be manually disconnected!"
      alert.informativeText = "A \(Branding.displayNoun.lowercased()) which is associated with a display will automatically disconnect when the associated display is disconnected."
      alert.runModal()
    }
    self.menu.populateAppMenu()
    VirtualDisplayManager.storeToPrefs()
  }

  @objc func discardAllVirtualDisplays(_: AnyObject?) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Do you want to discard all \(Branding.displayNounPlural.lowercased())?"
    alert.informativeText = "If you would like to use the \(Branding.displayNounPlural.lowercased()) later, it is better to use disconnect so macOS display configuration data is preserved."
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Discard")
    if alert.runModal() == .alertSecondButtonReturn {
      os_log("Removing virtual displays.", type: .info)
      VirtualDisplayManager.discardAll()
      self.menu.populateAppMenu()
      VirtualDisplayManager.storeToPrefs()
    }
  }

  @objc func disassociateAllVirtualDisplays(_: AnyObject?) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Do you want to disassociate all \(Branding.displayNounPlural.lowercased()) from all displays?"
    alert.informativeText = "Connected \(Branding.displayNounPlural.lowercased()) will remain connected after this operation."
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Disassociate")
    if alert.runModal() == .alertSecondButtonReturn {
      os_log("Disassociating virtual displays.", type: .info)
      for virtualDisplay in VirtualDisplayManager.getAll() {
        virtualDisplay.disassociateDisplay()
        self.menu.populateAppMenu()
        VirtualDisplayManager.storeToPrefs()
      }
    }
  }

  // MARK: *** Handlers - Display reconfiguration

  @objc func displayReconfiguration(dispatchedReconfigureID: Int = 0, force: Bool = false) {
    guard !self.skipReconfiguration else {
      os_log("Display reconfiguration is forcefully skipped", type: .info)
      return
    }
    if !force, dispatchedReconfigureID == 0 || self.isSleep {
      self.reconfigureID += 1
      os_log("Bumping reconfigureID to %{public}@", type: .info, String(self.reconfigureID))
      if !self.isSleep {
        let dispatchedReconfigureID = self.reconfigureID
        os_log("Displays to be reconfigured with reconfigureID %{public}@", type: .info, String(dispatchedReconfigureID))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
          self.displayReconfiguration(dispatchedReconfigureID: dispatchedReconfigureID)
        }
      }
    } else if dispatchedReconfigureID == self.reconfigureID || force {
      os_log("Request for display configuration with reconfigreID %{public}@", type: .info, String(dispatchedReconfigureID))
      self.reconfigureID = 0
      DisplayManager.configureDisplays()
      VirtualDisplayManager.connectDisconnectAssociated()
      self.menu.populateAppMenu()
      VirtualDisplayManager.storeToPrefs()
    }
  }

  // MARK: *** Handlers - Settings

  @objc func startAtLogin(_: AnyObject?) {
    let startAtLogin = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]])?.first { $0["Label"] as? String == "\(Bundle.main.bundleIdentifier!)Helper" }?["OnDemand"] as? Bool ?? false
    let identifier = "\(Bundle.main.bundleIdentifier!)Helper" as CFString
    SMLoginItemSetEnabled(identifier, !startAtLogin)
    self.menu.populateSettingsMenu()
  }

  @objc func reset(_: AnyObject?) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Are you sure you want to reset \(Branding.appName)?"
    alert.informativeText = "This restores the default settings and discards all \(Branding.displayNounPlural.lowercased()) in the process."
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Reset")
    if alert.runModal() == .alertSecondButtonReturn {
      VirtualDisplayManager.discardAll()
      VirtualDisplayManager.displayCounter = 0
      os_log("Cleared virtual displays.", type: .info)
      if let bundleID = Bundle.main.bundleIdentifier {
        prefs.removePersistentDomain(forName: bundleID)
      }
      os_log("Preferences reset complete.", type: .info)
      self.setDefaultPrefs()
      VirtualDisplayManager.restoreFromPrefs()
      self.menu.populateAppMenu()
      self.menu.populateSettingsMenu()
    }
  }

  @objc func hideMenuIcon(_: AnyObject?) {
    if prefs.bool(forKey: PrefKey.hideMenuIcon.rawValue) {
      prefs.set(false, forKey: PrefKey.hideMenuIcon.rawValue)
      self.menu.statusBarItem.isVisible = true
    } else {
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "Do you want to hide the menu icon?"
      alert.informativeText = "You can reveal the menu icon by launching the app again while the app is already running."
      alert.addButton(withTitle: "Hide")
      alert.addButton(withTitle: "No")
      if alert.runModal() == .alertFirstButtonReturn {
        prefs.set(true, forKey: PrefKey.hideMenuIcon.rawValue)
        self.menu.statusBarItem.isVisible = false
      }
    }
    self.menu.populateSettingsMenu()
  }

  @objc func SUEnableAutomaticChecks(_: AnyObject?) {
    prefs.set(!prefs.bool(forKey: PrefKey.SUEnableAutomaticChecks.rawValue), forKey: PrefKey.SUEnableAutomaticChecks.rawValue)
    self.menu.populateSettingsMenu()
  }

  @objc func disableTempSleep(_: AnyObject?) {
    prefs.set(!prefs.bool(forKey: PrefKey.disableTempSleep.rawValue), forKey: PrefKey.disableTempSleep.rawValue)
    self.menu.populateSettingsMenu()
  }

  @objc func reconnectAfterSleep(_: AnyObject?) {
    prefs.set(!prefs.bool(forKey: PrefKey.reconnectAfterSleep.rawValue), forKey: PrefKey.reconnectAfterSleep.rawValue)
    self.menu.populateSettingsMenu()
  }

  @objc func enable16K(_: AnyObject?) {
    if !prefs.bool(forKey: PrefKey.enable16K.rawValue) {
      let alert = NSAlert()
      alert.alertStyle = .critical
      alert.messageText = "Are you sure to enable 16K?"
      alert.informativeText = "Using \(Branding.displayNounPlural.lowercased()) over 8K can severely reduce performance on some setups."
      alert.addButton(withTitle: "Cancel")
      alert.addButton(withTitle: "Enable")
      if alert.runModal() == .alertFirstButtonReturn {
        return
      }
    }
    prefs.set(!prefs.bool(forKey: PrefKey.enable16K.rawValue), forKey: PrefKey.enable16K.rawValue)
    self.menu.populateSettingsMenu()
    VirtualDisplayManager.updateDefinitions()
  }

  @objc func hideLowResolutionOption(_: AnyObject?) {
    prefs.set(!prefs.bool(forKey: PrefKey.hideLowResolutionOption.rawValue), forKey: PrefKey.hideLowResolutionOption.rawValue)
    self.menu.populateSettingsMenu()
    self.menu.populateAppMenu()
  }

  // MARK: *** Handlers - Others

  @objc func about(_: AnyObject?) {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "UNKNOWN"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "UNKNOWN"
    let year = Calendar.current.component(.year, from: Date())
    let alert = NSAlert()
    alert.messageText = "About \(Branding.appName)"
    alert.informativeText = "Version \(version) Build \(build)\n\n\(Branding.appName) \(year) — an MIT-licensed fork of BetterDummy by @waydabber.\n\nCheck out the GitHub page for instructions or to report issues!"
    alert.addButton(withTitle: "Visit GitHub page")
    alert.addButton(withTitle: "OK")
    alert.alertStyle = NSAlert.Style.informational
    if alert.runModal() == .alertFirstButtonReturn {
      if let url = URL(string: "https://github.com/jm-armijo/ResolutionUnlocker#readme") {
        NSWorkspace.shared.open(url)
      }
    }
  }

  @objc func alwaysUseSerialForDisplayPrefsId(_: AnyObject?) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Using display serial number for association"
    alert.informativeText = "Changing this setting will disassociate all \(Branding.displayNounPlural.lowercased()) so you will need to reassociate them again. Do you want to continue?"
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Continue")
    if alert.runModal() == .alertFirstButtonReturn {
      return
    }
    prefs.set(!prefs.bool(forKey: PrefKey.alwaysUseSerialForDisplayPrefsId.rawValue), forKey: PrefKey.alwaysUseSerialForDisplayPrefsId.rawValue)
    for virtualDisplay in VirtualDisplayManager.getAll() {
      virtualDisplay.disassociateDisplay()
    }
    self.menu.populateAppMenu()
    VirtualDisplayManager.storeToPrefs()
    self.menu.populateSettingsMenu()
    self.menu.populateAppMenu()
  }

  @objc func buyMeACoffee(_: AnyObject?) {
    if let url = URL(string: "https://github.com/sponsors/jm-armijo?frequency=one-time&amount=10") {
      NSWorkspace.shared.open(url)
    }
  }

  // MARK: *** Handlers - Sleep and wake

  @objc func wakeNotification() {
    guard self.isSleep else {
      return
    }
    VirtualDisplayManager.sleepTempVirtualDisplay = nil
    os_log("Wake intercepted, removed temporary display if present.", type: .info)
    self.isSleep = false
    if prefs.bool(forKey: PrefKey.reconnectAfterSleep.rawValue) {
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
        if !self.isSleep {
          os_log("Delayed reconnecting virtual displays after wake.", type: .info)
          for virtualDisplay in VirtualDisplayManager.getAll() where !virtualDisplay.isConnected {
            _ = virtualDisplay.connect(sleepConnect: true)
          }
        }
      }
    }
  }

  @objc func sleepNotification() {
    guard !self.isSleep else {
      return
    }
    self.isSleep = true
    if VirtualDisplayManager.getCount() > 0, !prefs.bool(forKey: PrefKey.disableTempSleep.rawValue) {
      let maxWidth = 1920
      let maxHeight = 1080
      VirtualDisplayManager.sleepTempVirtualDisplay = VirtualDisplay.createCGVirtualDisplay(VirtualDisplayDefinition(maxWidth, maxHeight, 1, 1, 1, [60], "\(Branding.displayNoun) Temp", false), name: "\(Branding.displayNoun) Temp", serialNum: 0)
      os_log("Sleep intercepted, created temporary display with the size of %{public}@x%{public}@", type: .info, String(maxWidth), String(maxHeight))
    }
    if prefs.bool(forKey: PrefKey.reconnectAfterSleep.rawValue) {
      os_log("Disconnecting virtual displays on sleep.", type: .info)
      for virtualDisplay in VirtualDisplayManager.getAll() where virtualDisplay.isConnected {
        virtualDisplay.disconnect(sleepDisconnect: true)
      }
    }
  }
}
