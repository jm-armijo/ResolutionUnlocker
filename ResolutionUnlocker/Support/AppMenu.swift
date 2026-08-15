//
//  ResolutionUnlocker
//
//  Created by @waydabber
//

import AppKit
import os.log
import ServiceManagement

// Abstraction over the app-menu refresh so non-UI code (e.g. VirtualDisplayManager) can request
// a repopulate without depending on the global `app`/AppMenu directly.
protocol AppMenuRefreshing: AnyObject {
  func populateAppMenu()
}

class AppMenu: AppMenuRefreshing {
  var statusBarItem: NSStatusItem!

  let appMenu = NSMenu()
  let newMenu = NSMenu()
  let settingsMenu = NSMenu()

  func setupMenu() {
    self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
    if let button = self.statusBarItem.button {
      button.image = NSImage(named: "status")
    }
    self.statusBarItem.menu = self.appMenu
    self.statusBarItem.isVisible = !prefs.bool(forKey: PrefKey.hideMenuIcon.rawValue)
    self.populateNewMenu()
    self.populateSettingsMenu()
    self.populateAppMenu()
  }

  func emptyMenu(_ menuToEmpty: NSMenu) {
    var items: [NSMenuItem] = []
    for i in 0 ..< menuToEmpty.items.count {
      items.append(menuToEmpty.items[i])
    }
    for item in items {
      menuToEmpty.removeItem(item)
    }
  }

  func populateAppMenu() {
    self.emptyMenu(self.appMenu)
    var first = true
    for key in VirtualDisplayManager.definedDisplays.keys.sorted(by: <) {
      if let virtualDisplay = VirtualDisplayManager.getByNumber(key) {
        if !first {
          self.appMenu.addItem(NSMenuItem.separator())
        }
        self.addVirtualDisplayToMenu(virtualDisplay, key)
        first = false
      }
    }
    if VirtualDisplayManager.displayCounter >= 1 {
      self.appMenu.addItem(NSMenuItem.separator())
    }

    let newSubmenu = NSMenuItem(title: "Create new \(Branding.displayNoun.lowercased())", action: nil, keyEquivalent: "")
    newSubmenu.submenu = self.newMenu
    self.appMenu.addItem(newSubmenu)

    self.addManageMenu()

    self.appMenu.addItem(NSMenuItem.separator())

    let settingsSubmenu = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
    settingsSubmenu.submenu = self.settingsMenu
    self.appMenu.addItem(settingsSubmenu)
    // No "Check for updates..." item: update checking is disabled until an appcast is published.
    self.appMenu.addItem(NSMenuItem(title: "Buy me a coffee", action: #selector(app.buyMeACoffee(_:)), keyEquivalent: ""))
    self.appMenu.addItem(NSMenuItem.separator())
    self.appMenu.addItem(NSMenuItem(title: "Quit \(Branding.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
  }

  func populateSettingsMenu() {
    self.emptyMenu(self.settingsMenu)

    let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.headerTextColor, .font: NSFont.boldSystemFont(ofSize: 13)]

    let generalHeaderItem = NSMenuItem()
    generalHeaderItem.attributedTitle = NSAttributedString(string: "General settings", attributes: attrs)
    self.settingsMenu.addItem(generalHeaderItem)

    self.settingsMenu.addItem(self.checkmarkedMenuItem(checked: app.getStartAtLogin(), title: "Start at login", action: #selector(app.startAtLogin)))
    // "Automatically check for updates" toggle omitted: update checking is disabled until an appcast is published.
    self.settingsMenu.addItem(self.checkmarkedMenuItem(checked: prefs.bool(forKey: PrefKey.hideMenuIcon.rawValue), title: "Hide menu icon", action: #selector(app.hideMenuIcon)))

    // ---
    self.settingsMenu.addItem(NSMenuItem.separator())

    let resolutionsHeaderItem = NSMenuItem()
    resolutionsHeaderItem.attributedTitle = NSAttributedString(string: "\(Branding.displayNoun) management", attributes: attrs)
    self.settingsMenu.addItem(resolutionsHeaderItem)

    self.settingsMenu.addItem(self.checkmarkedMenuItem(checked: prefs.bool(forKey: PrefKey.enable16K.rawValue), title: "Enable up to 16K resolutions", action: #selector(app.enable16K)))
    self.settingsMenu.addItem(self.checkmarkedMenuItem(checked: !prefs.bool(forKey: PrefKey.hideLowResolutionOption.rawValue), title: "Show low resolution (non-HiDPI) options", action: #selector(app.hideLowResolutionOption)))
    self.settingsMenu.addItem(self.checkmarkedMenuItem(checked: prefs.bool(forKey: PrefKey.alwaysUseSerialForDisplayPrefsId.rawValue), title: "Use display serial number for association", action: #selector(app.alwaysUseSerialForDisplayPrefsId(_:))))

    // ---
    self.settingsMenu.addItem(NSMenuItem.separator())

    let sleepHeaderItem = NSMenuItem()
    sleepHeaderItem.attributedTitle = NSAttributedString(string: "Sleep settings", attributes: attrs)
    self.settingsMenu.addItem(sleepHeaderItem)

    self.settingsMenu.addItem(self.checkmarkedMenuItem(checked: !prefs.bool(forKey: PrefKey.disableTempSleep.rawValue), title: "Use mirrored \(Branding.displayNoun.lowercased()) sleep workaround", action: #selector(app.disableTempSleep)))
    self.settingsMenu.addItem(self.checkmarkedMenuItem(checked: prefs.bool(forKey: PrefKey.reconnectAfterSleep.rawValue), title: "Disconnect and reconnect on sleep", action: #selector(app.reconnectAfterSleep)))

    // ---

    self.settingsMenu.addItem(NSMenuItem.separator())
    self.settingsMenu.addItem(NSMenuItem(title: "About \(Branding.appName)", action: #selector(app.about(_:)), keyEquivalent: ""))
    self.settingsMenu.addItem(NSMenuItem(title: "Reset \(Branding.appName)", action: #selector(app.reset(_:)), keyEquivalent: ""))
  }

  func populateNewMenu() {
    self.emptyMenu(self.newMenu)
    for key in VirtualDisplayManager.definitions.keys.sorted() {
      if let definition = VirtualDisplayManager.definitions[key] {
        let item = NSMenuItem(title: "\(definition.description)", action: #selector(app.createVirtualDisplay(_:)), keyEquivalent: "")
        item.tag = key
        self.newMenu.addItem(item)
        if definition.addSeparatorAfter {
          self.newMenu.addItem(NSMenuItem.separator())
        }
      }
    }
    os_log("New virtual display menu populated.", type: .info)
  }

  func addManageMenu() {
    let manageMenu = NSMenu()

    if VirtualDisplayManager.displayCounter > 1 {
      var isThereDisconnected = false
      var isThereConnected = false
      var isThereAssociated = false
      var isThereAny = false
      for virtualDisplay in VirtualDisplayManager.getAll() {
        isThereAny = true
        if virtualDisplay.isConnected {
          isThereConnected = true
        }
        if !virtualDisplay.isConnected {
          isThereDisconnected = true
        }
        if virtualDisplay.hasAssociatedDisplay() {
          isThereAssociated = true
        }
      }

      if isThereDisconnected {
        manageMenu.addItem(NSMenuItem(title: "Connect all \(Branding.displayNounPlural.lowercased())", action: #selector(app.connectAllVirtualDisplays(_:)), keyEquivalent: ""))
      }
      if isThereConnected {
        manageMenu.addItem(NSMenuItem(title: "Disconnect all \(Branding.displayNounPlural.lowercased())", action: #selector(app.disconnectAllVirtualDisplays(_:)), keyEquivalent: ""))
      }
      if isThereAssociated {
        manageMenu.addItem(NSMenuItem(title: "Disassociate all \(Branding.displayNounPlural.lowercased())", action: #selector(app.disassociateAllVirtualDisplays(_:)), keyEquivalent: ""))
      }
      if isThereAny {
        manageMenu.addItem(NSMenuItem(title: "Discard all \(Branding.displayNounPlural.lowercased())", action: #selector(app.discardAllVirtualDisplays(_:)), keyEquivalent: ""))
        let manageSubmenu = NSMenuItem(title: "Manage \(Branding.displayNounPlural.lowercased())", action: nil, keyEquivalent: "")
        manageSubmenu.submenu = manageMenu
        self.appMenu.addItem(manageSubmenu)
      }
    }
  }

  func getResolutionSubmenuItem(_ virtualDisplay: VirtualDisplay, _ number: Int) -> NSMenuItem? {
    let resolutionMenu = NSMenu()
    if let resolutions = DisplayManager.getDisplayById(virtualDisplay.displayIdentifier)?.resolutions {
      let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.headerTextColor, .font: NSFont.boldSystemFont(ofSize: 13)]
      let hidpiHeaderItem = NSMenuItem()
      hidpiHeaderItem.attributedTitle = NSAttributedString(string: "HiDPI resolutions", attributes: attrs)
      resolutionMenu.addItem(hidpiHeaderItem)
      for resolution in resolutions.sorted(by: { $0.0 < $1.0 }) where resolution.value.height >= 720 && resolution.value.hiDPI == true {
        resolutionMenu.addItem(self.checkmarkedMenuItem(checked: resolution.value.isActive, title: "\(resolution.value.width)x\(resolution.value.height)", tag: number * 256 * 256 + resolution.key, action: #selector(app.virtualDisplayResolution(_:)), radio: true))
      }
      if !prefs.bool(forKey: PrefKey.hideLowResolutionOption.rawValue) {
        resolutionMenu.addItem(NSMenuItem.separator())
        let hidpiHeaderItem = NSMenuItem()
        hidpiHeaderItem.attributedTitle = NSAttributedString(string: "Low resolutions", attributes: attrs)
        resolutionMenu.addItem(hidpiHeaderItem)
        for resolution in resolutions.sorted(by: { $0.0 < $1.0 }) where resolution.value.height >= 720 && resolution.value.hiDPI == false {
          resolutionMenu.addItem(self.checkmarkedMenuItem(checked: resolution.value.isActive, title: "\(resolution.value.width)x\(resolution.value.height) (low)", tag: number * 256 * 256 + resolution.key, action: #selector(app.virtualDisplayResolution(_:)), radio: true))
        }
      }
    } else {
      let unavailableItem = NSMenuItem(title: "Unavailable", action: nil, keyEquivalent: "")
      unavailableItem.isEnabled = false
      resolutionMenu.addItem(unavailableItem)
    }
    let resolutionSubmenu = NSMenuItem(title: "Set resolution", action: nil, keyEquivalent: "")
    resolutionSubmenu.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "icon")
    resolutionSubmenu.submenu = resolutionMenu
    return resolutionSubmenu
  }

  func getAssociateSubmenuItem(_ virtualDisplay: VirtualDisplay, _ number: Int) -> NSMenuItem {
    let associateMenu = NSMenu()
    var foundAssociatedDisplay = false
    for displayNumber in DisplayManager.displays.keys {
      if let display = DisplayManager.displays[displayNumber], !display.isManaged {
        var checked = false
        if display.prefsId == virtualDisplay.associatedDisplayPrefsId, virtualDisplay.hasAssociatedDisplay() {
          checked = true
          foundAssociatedDisplay = true
        }
        associateMenu.addItem(self.checkmarkedMenuItem(checked: checked, title: display.name, tag: 0x100 * displayNumber + number, action: #selector(app.associateVirtualDisplay(_:)), radio: true))
      }
    }
    if virtualDisplay.hasAssociatedDisplay(), !foundAssociatedDisplay {
      associateMenu.addItem(self.checkmarkedMenuItem(checked: true, title: "\(virtualDisplay.associatedDisplayName) (disconnected)", tag: 0, action: #selector(app.associateVirtualDisplay(_:)), radio: true))
    }
    associateMenu.addItem(self.checkmarkedMenuItem(checked: !virtualDisplay.hasAssociatedDisplay(), title: "None (disassociated)", tag: number, action: #selector(app.disassociateVirtualDisplay(_:)), radio: true))
    let associateSubmenu = NSMenuItem(title: virtualDisplay.hasAssociatedDisplay() ? "Change association" : "Set up association", action: nil, keyEquivalent: "")
    associateSubmenu.image = NSImage(systemSymbolName: virtualDisplay.hasAssociatedDisplay() ? "link" : "link.badge.plus", accessibilityDescription: "icon")
    associateSubmenu.submenu = associateMenu
    return associateSubmenu
  }

  func checkmarkedMenuItem(checked: Bool, title: String, tag: Int? = nil, action: Selector, radio: Bool = false) -> NSMenuItem {
    let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
    if let tag = tag {
      menuItem.tag = tag
    }
    menuItem.state = checked ? .on : .off
    menuItem.onStateImage = nil
    menuItem.image = NSImage(systemSymbolName: checked ? (radio ? "record.circle" : "checkmark.circle") : (radio ? "circle" : "circle"), accessibilityDescription: "icon")
    return menuItem
  }

  func addVirtualDisplayToMenu(_ virtualDisplay: VirtualDisplay, _ number: Int) {
    let headerItem = NSMenuItem()
    let attributedHeader = NSMutableAttributedString()
    var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.headerTextColor, .font: NSFont.boldSystemFont(ofSize: 13)]
    attributedHeader.append(NSAttributedString(string: "\(virtualDisplay.getName())", attributes: attrs))
    attrs = [.foregroundColor: NSColor.systemGray, .font: NSFont.systemFont(ofSize: 13)]
    attributedHeader.append(NSAttributedString(string: " (\(virtualDisplay.getSerialNumber()))", attributes: attrs))
    headerItem.attributedTitle = attributedHeader
    self.appMenu.addItem(headerItem)
    self.appMenu.addItem(self.getAssociateSubmenuItem(virtualDisplay, number))
    if virtualDisplay.isConnected, let resolutionSubmenuItem = self.getResolutionSubmenuItem(virtualDisplay, number) {
      self.appMenu.addItem(resolutionSubmenuItem)
    }
    self.appMenu.addItem(self.checkmarkedMenuItem(checked: virtualDisplay.isConnected, title: "Connected\(virtualDisplay.hasAssociatedDisplay() ? " (automatic)" : "")", tag: number, action: #selector(app.connectDisconnectVirtualDisplay)))
    let deleteItem = NSMenuItem(title: "Discard \(Branding.displayNoun.lowercased())", action: #selector(app.discardVirtualDisplay(_:)), keyEquivalent: "")
    deleteItem.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "icon")
    deleteItem.tag = number
    self.appMenu.addItem(deleteItem)
  }
}
