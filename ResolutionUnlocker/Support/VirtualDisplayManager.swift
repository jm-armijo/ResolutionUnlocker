//
//  ResolutionUnlocker
//
//  Created by @waydabber
//

import Foundation
import os.log

class VirtualDisplayManager {
  struct DefinedVirtualDisplay {
    var virtualDisplay: VirtualDisplay
    var definitionId: Int?
  }

  static var definedDisplays: [Int: DefinedVirtualDisplay] = [:]
  static var displayCounter: Int = 0 // This is an ever increasing temporary number, does not reflect the actual number of virtual displays.
  static var sleepTempVirtualDisplay: CGVirtualDisplay?
  static var definitions: [Int: VirtualDisplayDefinition] = [:]
  // Injected UI seam so restoreFromPrefs can refresh the menu without referencing
  // the global `app`. Set once by AppDelegate at launch; nil in isolated unit tests.
  static weak var menuRefresher: AppMenuRefreshing?

  static func createByDefinitionId(_ definitionId: Int, isPortrait: Bool = false, serialNum: UInt32 = 0, doConnect: Bool = true) -> Int? {
    if let definition = self.definitions[definitionId] {
      return self.create(definition, definitionId: definitionId, isPortrait: isPortrait, serialNum: serialNum, doConnect: doConnect)
    }
    return nil
  }

  static func create(_ definition: VirtualDisplayDefinition, definitionId: Int? = nil, isPortrait _: Bool = false, serialNum: UInt32 = 0, doConnect: Bool = true) -> Int {
    let virtualDisplay = VirtualDisplay(definition: definition, serialNum: serialNum, doConnect: doConnect)
    self.displayCounter += 1
    self.definedDisplays[self.displayCounter] = DefinedVirtualDisplay(virtualDisplay: virtualDisplay, definitionId: definitionId)
    return self.displayCounter
  }

  static func getAll() -> [VirtualDisplay] {
    var virtualDisplays: [VirtualDisplay] = []
    for definedDisplay in self.definedDisplays.values {
      virtualDisplays.append(definedDisplay.virtualDisplay)
    }
    return virtualDisplays
  }

  static func discardByNumber(_ number: Int) {
    self.definedDisplays[number] = nil
  }

  static func discardAll() {
    self.definedDisplays = [:]
    self.displayCounter = 0
  }

  static func getByNumber(_ number: Int) -> VirtualDisplay? {
    self.definedDisplays[number]?.virtualDisplay
  }

  static func getDefinitionIdByNumber(_ number: Int) -> Int? {
    self.definedDisplays[number]?.definitionId
  }

  static func getCount() -> Int {
    self.definedDisplays.count
  }

  static func connectDisconnectAssociated() {
    var didChange = false
    for virtualDisplay in self.getAll() {
      if virtualDisplay.hasAssociatedDisplay() {
        if DisplayManager.getDisplayByPrefsId(virtualDisplay.associatedDisplayPrefsId) != nil {
          if !virtualDisplay.isConnected {
            os_log("Connecting associated virtual display %{public}@ for display %{public}@", type: .info, virtualDisplay.getName(), virtualDisplay.associatedDisplayPrefsId)
            app.skipReconfiguration = true
            _ = virtualDisplay.connect()
            didChange = true
          }
        } else {
          if virtualDisplay.isConnected {
            os_log("Disconnecting associated virtual display %{public}@ for lack of display %{public}@", type: .info, virtualDisplay.getName(), virtualDisplay.associatedDisplayPrefsId)
            app.skipReconfiguration = true
            virtualDisplay.disconnect()
            didChange = true
          }
        }
      }
    }
    if didChange {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        app.skipReconfiguration = false
      }
    }
  }

  static func getDefinedByDisplayId(_ displayID: CGDirectDisplayID) -> DefinedVirtualDisplay? {
    self.definedDisplays.values.first { $0.virtualDisplay.displayIdentifier == displayID }
  }

  static func getByDisplayId(_ displayID: CGDirectDisplayID) -> VirtualDisplay? {
    self.getDefinedByDisplayId(displayID)?.virtualDisplay
  }

  static func updateDefinitions() {
    let refreshRates: [Double] = [60] // [24, 25, 30, 48, 50, 60, 90, 120] -- only 60Hz seems to be useful in practice
    self.definitions = [
      10: VirtualDisplayDefinition(16, 9, 2, refreshRates, "16:9 (HD/4K/5K/6K)", false),
      20: VirtualDisplayDefinition(16, 10, 2, refreshRates, "16:10 (W*XGA)", false),
      30: VirtualDisplayDefinition(16, 12, 2, refreshRates, "4:3 (VGA, iPad)", false),
      40: VirtualDisplayDefinition(256, 135, 2, refreshRates, "17:9 (4K-DCI)", true),
      50: VirtualDisplayDefinition(64, 27, 2, refreshRates, "21.3:9 (UW-HD/4K/5K)", false),
      60: VirtualDisplayDefinition(43, 18, 2, refreshRates, "21.5:9 (UW-QHD)", false),
      70: VirtualDisplayDefinition(24, 10, 1, refreshRates, "24:10 (UW-QHD+)", false),
      80: VirtualDisplayDefinition(32, 10, 1, refreshRates, "32:10 (D-W*XGA)", false),
      90: VirtualDisplayDefinition(32, 9, 2, refreshRates, "32:9 (D-HD/QHD)", true),
      100: VirtualDisplayDefinition(20, 20, 2, refreshRates, "1:1 (Square)", true),
      110: VirtualDisplayDefinition(9, 16, 2, refreshRates, "9:16 (HD/4K/5K/6K - Portrait)", false),
      120: VirtualDisplayDefinition(10, 16, 2, refreshRates, "10:16 (W*XGA - Portrait)", false),
      130: VirtualDisplayDefinition(12, 16, 2, refreshRates, "12:16 (VGA - Portrait)", false),
      140: VirtualDisplayDefinition(135, 256, 2, refreshRates, "9:17 (4K-DCI - Portrait)", true),
      210: VirtualDisplayDefinition(15, 10, 2, refreshRates, "3:2 (Photography)", false),
      220: VirtualDisplayDefinition(15, 12, 2, refreshRates, "5:4 (Photography)", true),
      350: VirtualDisplayDefinition(152, 100, 1, refreshRates, "15.2:10 (iPad Mini 2021)", false),
      360: VirtualDisplayDefinition(66, 41, 2, refreshRates, "23:16 (iPad Air 2020)", false),
      370: VirtualDisplayDefinition(199, 139, 2, refreshRates, "14.3:10 (iPad Pro 11\")", false),
    ]
    for definedDisplay in self.definedDisplays.values {
      if let definitionId = definedDisplay.definitionId, let definition = self.definitions[definitionId] {
        definedDisplay.virtualDisplay.definition = definition
      }
      if definedDisplay.virtualDisplay.isConnected {
        definedDisplay.virtualDisplay.disconnect()
        _ = definedDisplay.virtualDisplay.connect()
      }
    }
  }

  static func restoreFromPrefs() {
    os_log("Restoring virtual displays.", type: .info)
    guard prefs.integer(forKey: PrefKey.numOfVirtualDisplays.rawValue) > 0 else {
      return
    }
    for i in 1 ... prefs.integer(forKey: PrefKey.numOfVirtualDisplays.rawValue) where prefs.object(forKey: "\(PrefKey.display.rawValue)\(i)") != nil {
      if let number = VirtualDisplayManager.createByDefinitionId(prefs.integer(forKey: "\(PrefKey.display.rawValue)\(i)"), serialNum: UInt32(prefs.integer(forKey: "\(PrefKey.serial.rawValue)\(i)")), doConnect: false) {
        if let virtualDisplay = VirtualDisplayManager.getByNumber(number) {
          virtualDisplay.associatedDisplayPrefsId = prefs.string(forKey: "\(PrefKey.associatedDisplayPrefsId.rawValue)\(i)") ?? ""
          virtualDisplay.associatedDisplayName = prefs.string(forKey: "\(PrefKey.associatedDisplayName.rawValue)\(i)") ?? ""
          if prefs.bool(forKey: "\(PrefKey.isConnected.rawValue)\(i)") {
            _ = virtualDisplay.connect()
          }
        }
      }
    }
    self.menuRefresher?.populateAppMenu()
  }

  static func storeToPrefs() {
    os_log("Storing preferences.", type: .info)
    prefs.set(VirtualDisplayManager.getCount(), forKey: PrefKey.numOfVirtualDisplays.rawValue)
    guard VirtualDisplayManager.getCount() > 0 else {
      return
    }
    var i = 1
    for key in VirtualDisplayManager.definedDisplays.keys.sorted(by: <) {
      if let definedDisplay = VirtualDisplayManager.definedDisplays[key] {
        prefs.set(definedDisplay.definitionId, forKey: "\(PrefKey.display.rawValue)\(i)")
        prefs.set(definedDisplay.virtualDisplay.serialNum, forKey: "\(PrefKey.serial.rawValue)\(i)")
        prefs.set(definedDisplay.virtualDisplay.isConnected, forKey: "\(PrefKey.isConnected.rawValue)\(i)")
        prefs.set(definedDisplay.virtualDisplay.associatedDisplayPrefsId, forKey: "\(PrefKey.associatedDisplayPrefsId.rawValue)\(i)")
        prefs.set(definedDisplay.virtualDisplay.associatedDisplayName, forKey: "\(PrefKey.associatedDisplayName.rawValue)\(i)")
        i += 1
      }
    }
  }
}
