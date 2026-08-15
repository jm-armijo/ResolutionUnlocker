//
//  ResolutionUnlocker
//
//  Created by @waydabber
//

import Cocoa
import Foundation
import os.log

class Display: Equatable {
  struct Resolution {
    var modeNumber: UInt32
    var width: UInt32
    var height: UInt32
    var bitDepth: UInt32
    var refreshRate: UInt16
    var hiDPI: Bool
    var isActive: Bool
  }

  let identifier: CGDirectDisplayID
  let prefsId: String
  var name: String
  var vendorNumber: UInt32?
  var modelNumber: UInt32?
  var serialNumber: UInt32?
  var resolutions: [Int: Resolution] = [:]
  var currentResolution: Int = 0
  var width: UInt32 = 0
  var height: UInt32 = 0
  var pixelWidth: UInt32 = 0
  var pixelHeight: UInt32 = 0
  var isHiDPI: Bool = false

  static func == (lhs: Display, rhs: Display) -> Bool {
    lhs.identifier == rhs.identifier
  }

  var isVirtual: Bool = false
  var isManaged: Bool = false // Created by this app (see DisplayManager.isManaged)

  private let modeProvider: DisplayModeProviding

  init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, serialNumber: UInt32?, isVirtual: Bool = false, isManaged: Bool = false, modeProvider: DisplayModeProviding = SystemDisplayModeProvider()) {
    self.identifier = identifier
    self.name = name
    self.vendorNumber = vendorNumber
    self.modelNumber = modelNumber
    self.serialNumber = serialNumber
    self.isVirtual = isVirtual
    self.isManaged = isManaged
    self.modeProvider = modeProvider
    self.prefsId = "(" + String(name.filter { !$0.isWhitespace }) + String(vendorNumber ?? 0) + String(modelNumber ?? 0) + "@" + (self.isVirtual || prefs.bool(forKey: PrefKey.alwaysUseSerialForDisplayPrefsId.rawValue) ? String(self.serialNumber ?? 9999) : String(identifier)) + ")"
    os_log("Display init with prefsIdentifier %{public}@", type: .info, self.prefsId)
    self.updateResolutions()
  }

  func isBuiltIn() -> Bool {
    if CGDisplayIsBuiltin(self.identifier) != 0 {
      return true
    } else {
      return false
    }
  }

  func updateResolutions() {
    let count = self.modeProvider.modeCount(for: self.identifier)
    let currentIndex = self.modeProvider.currentModeIndex(for: self.identifier)
    self.resolutions = Display.makeResolutions(count: count, currentIndex: currentIndex) { index in
      self.modeProvider.modeInfo(for: self.identifier, index: index)
    }
    self.currentResolution = 0
    for (index, resolution) in self.resolutions where resolution.isActive {
      self.currentResolution = index
      self.width = resolution.width
      self.height = resolution.height
      self.isHiDPI = resolution.hiDPI
      self.pixelWidth = self.width * (self.isHiDPI ? 2 : 1)
      self.pixelHeight = self.height * (self.isHiDPI ? 2 : 1)
    }
  }

  // Pure resolution-building logic, extracted from updateResolutions so it can be unit
  // tested with an injected mode provider. The count guard makes a zero or negative mode
  // count safe; the previous `0 ... count - 1` trapped when a display reported no modes.
  static func makeResolutions(count: Int, currentIndex: Int, info: (Int) -> DisplayModeInfo) -> [Int: Resolution] {
    var resolutions: [Int: Resolution] = [:]
    guard count > 0 else { return resolutions }
    for i in 0 ..< count {
      let mode = info(i)
      resolutions[i] = Resolution(
        modeNumber: mode.modeNumber,
        width: mode.width,
        height: mode.height,
        bitDepth: mode.depth,
        refreshRate: mode.refreshRate,
        hiDPI: Int(mode.density) > 1 ? true : false,
        isActive: currentIndex == i ? true : false
      )
    }
    return resolutions
  }

  func changeResolution(resolutionItemNumber: Int32) {
    os_log("Changing resolution for display %{public}@ to %{public}@", type: .info, self.prefsId, "\(resolutionItemNumber)")
    app.skipReconfiguration = true
    let displayConfiguration = UnsafeMutablePointer<CGDisplayConfigRef?>.allocate(capacity: 1)
    defer {
      displayConfiguration.deallocate()
    }
    CGBeginDisplayConfiguration(displayConfiguration)
    CGSConfigureDisplayMode(displayConfiguration.pointee, self.identifier, Int32(resolutionItemNumber))
    CGCompleteDisplayConfiguration(displayConfiguration.pointee, CGConfigureOption.permanently)
    self.updateResolutions()
    app.skipReconfiguration = false
  }
}
