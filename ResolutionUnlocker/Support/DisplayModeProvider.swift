//
//  ResolutionUnlocker
//
//  Dependency-inversion seam for reading a display's modes. Display used to call the
//  private CGS* APIs inline, which made its resolution-building logic impossible to
//  unit-test. The logic now depends on this abstraction; production uses
//  SystemDisplayModeProvider, tests inject a fake.
//

import CoreGraphics
import Foundation

/// A single display mode, decoupled from the private `CGSDisplayMode` C struct so the
/// pure resolution-building logic (and its tests) never touch the private API surface.
struct DisplayModeInfo {
  let modeNumber: UInt32
  let width: UInt32
  let height: UInt32
  let depth: UInt32
  let refreshRate: UInt16
  let density: Float
}

/// Abstraction over the private display-mode query APIs.
protocol DisplayModeProviding {
  func modeCount(for displayID: CGDirectDisplayID) -> Int
  func currentModeIndex(for displayID: CGDirectDisplayID) -> Int
  func modeInfo(for displayID: CGDirectDisplayID, index: Int) -> DisplayModeInfo
}

/// Production implementation backed by the private CoreGraphics/SkyLight calls that
/// previously lived directly inside `Display.updateResolutions()`.
struct SystemDisplayModeProvider: DisplayModeProviding {
  func modeCount(for displayID: CGDirectDisplayID) -> Int {
    var count: Int32 = 0
    CGSGetNumberOfDisplayModes(displayID, &count)
    return Int(count)
  }

  func currentModeIndex(for displayID: CGDirectDisplayID) -> Int {
    var current: Int32 = 0
    CGSGetCurrentDisplayMode(displayID, &current)
    return Int(current)
  }

  func modeInfo(for displayID: CGDirectDisplayID, index: Int) -> DisplayModeInfo {
    var mode = CGSDisplayMode()
    CGSGetDisplayModeDescriptionOfLength(displayID, Int32(index), &mode, Int32(MemoryLayout<CGSDisplayMode>.size))
    return DisplayModeInfo(
      modeNumber: mode.modeNumber,
      width: mode.width,
      height: mode.height,
      depth: mode.depth,
      refreshRate: mode.freq,
      density: mode.density
    )
  }
}
