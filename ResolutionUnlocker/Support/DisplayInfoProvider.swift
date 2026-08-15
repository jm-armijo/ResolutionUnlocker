//
//  ResolutionUnlocker
//
//  Dependency-inversion seam for CoreDisplay's per-display info dictionary. DisplayManager
//  used to call CoreDisplay_DisplayCreateInfoDictionary inline, which made its name/virtual/
//  managed-display classification impossible to unit-test. That logic now depends on this abstraction;
//  production uses SystemDisplayInfoProvider, tests inject a stub dictionary.
//

import CoreGraphics
import Foundation

protocol DisplayInfoProviding {
  func infoDictionary(for displayID: CGDirectDisplayID) -> NSDictionary?
}

struct SystemDisplayInfoProvider: DisplayInfoProviding {
  func infoDictionary(for displayID: CGDirectDisplayID) -> NSDictionary? {
    (CoreDisplay_DisplayCreateInfoDictionary(displayID))?.takeRetainedValue() as NSDictionary?
  }
}
