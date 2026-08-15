//
//  ResolutionUnlocker
//
//  Created by @waydabber
//

import Cocoa
import Foundation
import os.log

class VirtualDisplay: Equatable {
  var cgVirtualDisplay: CGVirtualDisplay?
  var definition: VirtualDisplayDefinition
  let serialNum: UInt32
  var isConnected: Bool = false
  var isSleepDisconnected: Bool = false
  var associatedDisplayPrefsId: String = ""
  var associatedDisplayName: String = ""
  var displayIdentifier: CGDirectDisplayID = 0 // This contains valid info only if the display is connected

  static func == (lhs: VirtualDisplay, rhs: VirtualDisplay) -> Bool {
    lhs.serialNum == rhs.serialNum
  }

  init(definition: VirtualDisplayDefinition, serialNum: UInt32 = 0, doConnect: Bool = true) {
    var storedSerialNum: UInt32 = serialNum
    if storedSerialNum == 0 {
      storedSerialNum = UInt32.random(in: 0 ... UInt32.max)
    }
    self.definition = definition
    self.serialNum = storedSerialNum
    if doConnect {
      _ = self.connect()
    }
  }

  func getName() -> String {
    "\(Branding.displayNoun) \(self.definition.description.components(separatedBy: " ").first ?? self.definition.description)"
  }

  func getMenuItemTitle() -> String {
    "\(self.definition.description.components(separatedBy: " ").first ?? "") - #\(String(format: "%02X", self.serialNum))"
  }

  func getSerialNumber() -> String {
    "\(String(format: "%02X", self.serialNum))"
  }

  func connect(sleepConnect: Bool = false) -> Bool {
    guard sleepConnect && self.isSleepDisconnected || !sleepConnect else {
      return false
    }
    self.isSleepDisconnected = false
    if self.cgVirtualDisplay != nil || self.isConnected {
      os_log("Attempted to connect the already connected display %{public}@. Interpreting as connect cycle.", type: .info, "\(self.getName())")
      self.disconnect()
    }
    let name: String = self.getName()
    if let cgVirtualDisplay = VirtualDisplay.createCGVirtualDisplay(self.definition, name: name, serialNum: self.serialNum) {
      self.cgVirtualDisplay = cgVirtualDisplay
      self.displayIdentifier = cgVirtualDisplay.displayID
      self.isConnected = true
      os_log("Display %{public}@ successfully connected", type: .info, "\(name)")
      return true
    } else {
      os_log("Failed to connect display %{public}@", type: .info, "\(name)")
      return false
    }
  }

  func associateDisplay(display: Display) {
    self.associatedDisplayPrefsId = display.prefsId
    self.associatedDisplayName = display.name
  }

  func disassociateDisplay() {
    self.associatedDisplayPrefsId = ""
    self.associatedDisplayName = ""
  }

  func hasAssociatedDisplay() -> Bool {
    self.associatedDisplayPrefsId == "" ? false : true
  }

  func disconnect(sleepDisconnect: Bool = false) {
    self.cgVirtualDisplay = nil
    self.isConnected = false
    self.isSleepDisconnected = sleepDisconnect
    os_log("Disconnected virtual display: %{public}@", type: .info, "\(self.getName())")
  }

  struct ModeSpec: Equatable {
    let width: UInt32
    let height: UInt32
    let refreshRate: Double
  }

  // Pure mode-list construction, extracted from createCGVirtualDisplay so it can be unit
  // tested without creating a real virtual display. Each (multiplier, refresh rate)
  // combination yields its own mode; the previous version indexed by multiplier only,
  // so multiple refresh rates overwrote each other and only the last survived.
  static func makeModeSpecs(for definition: VirtualDisplayDefinition) -> [ModeSpec] {
    var specs: [ModeSpec] = []
    for multiplier in definition.minMultiplier ... definition.maxMultiplier {
      for refreshRate in definition.refreshRates {
        let width = UInt32(definition.aspectWidth * multiplier * definition.multiplierStep)
        let height = UInt32(definition.aspectHeight * multiplier * definition.multiplierStep)
        specs.append(ModeSpec(width: width, height: height, refreshRate: refreshRate))
      }
    }
    return specs
  }

  static func createCGVirtualDisplay(_ definition: VirtualDisplayDefinition, name: String, serialNum: UInt32, hiDPI: Bool = true) -> CGVirtualDisplay? {
    os_log("Creating virtual display: %{public}@", type: .info, "\(name)")
    if let descriptor = CGVirtualDisplayDescriptor() {
      os_log("- Preparing descriptor...", type: .info)
      descriptor.queue = DispatchQueue.global(qos: .userInteractive)
      descriptor.name = name
      descriptor.whitePoint = CGPoint(x: 0.950, y: 1.000) // "Taken from Generic RGB Profile.icc"
      descriptor.redPrimary = CGPoint(x: 0.454, y: 0.242) // "Taken from Generic RGB Profile.icc"
      descriptor.greenPrimary = CGPoint(x: 0.353, y: 0.674) // "Taken from Generic RGB Profile.icc"
      descriptor.bluePrimary = CGPoint(x: 0.157, y: 0.084) // "Taken from Generic RGB Profile.icc"
      descriptor.maxPixelsWide = UInt32(definition.aspectWidth * definition.multiplierStep * definition.maxMultiplier)
      descriptor.maxPixelsHigh = UInt32(definition.aspectHeight * definition.multiplierStep * definition.maxMultiplier)
      // The virtual display will be fixed at 24" for now
      let diagonalSizeRatio: Double = (24 * 25.4) / sqrt(Double(definition.aspectWidth * definition.aspectWidth + definition.aspectHeight * definition.aspectHeight))
      descriptor.sizeInMillimeters = CGSize(width: Double(definition.aspectWidth) * diagonalSizeRatio, height: Double(definition.aspectHeight) * diagonalSizeRatio)
      descriptor.serialNum = serialNum
      descriptor.productID = UInt32(min(definition.aspectWidth - 1, 255) * 256 + min(definition.aspectHeight - 1, 255))
      descriptor.vendorID = UInt32(0xF0F0)
      if let display = CGVirtualDisplay(descriptor: descriptor) {
        os_log("- Creating display, preparing modes...", type: .info)
        let modes = VirtualDisplay.makeModeSpecs(for: definition).map { CGVirtualDisplayMode(width: $0.width, height: $0.height, refreshRate: $0.refreshRate)! }
        if let settings = CGVirtualDisplaySettings() {
          os_log("- Preparing settings for display...", type: .info)
          settings.hiDPI = hiDPI ? 1 : 0
          settings.modes = modes as [Any]
          if display.applySettings(settings) {
            os_log("- Settings are successfully applied. Virtual display ID is %{public}@", type: .info, String(display.displayID))
            return display
          }
        }
      }
    }
    return nil
  }
}
