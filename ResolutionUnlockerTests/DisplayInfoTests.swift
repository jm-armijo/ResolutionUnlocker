//
//  ResolutionUnlockerTests
//
//  Phase 2 — unit tests for the DisplayManager classification logic unlocked by the
//  DisplayInfoProviding seam. The pure functions are tested directly with stub
//  dictionaries; the id-based wrappers are tested through a stub provider.
//

import XCTest
import CoreGraphics
@testable import ResolutionUnlocker

private struct StubInfoProvider: DisplayInfoProviding {
  let info: NSDictionary?
  func infoDictionary(for _: CGDirectDisplayID) -> NSDictionary? { info }
}

final class DisplayInfoTests: XCTestCase {
  func testDisplayNamePrefersEnUS() {
    let info: NSDictionary = ["DisplayProductName": ["en_US": "LG UltraFine", "de_DE": "LG Fein"]]
    XCTAssertEqual(DisplayManager.displayName(from: info), "LG UltraFine")
  }

  func testDisplayNameFallsBackToAnyLocaleWhenNoEnUS() {
    let info: NSDictionary = ["DisplayProductName": ["fr_FR": "Ecran"]]
    XCTAssertEqual(DisplayManager.displayName(from: info), "Ecran")
  }

  func testDisplayNameDefaultsToUnknown() {
    XCTAssertEqual(DisplayManager.displayName(from: nil), "Unknown")
    XCTAssertEqual(DisplayManager.displayName(from: [:] as NSDictionary), "Unknown")
    XCTAssertEqual(DisplayManager.displayName(from: ["Other": 1] as NSDictionary), "Unknown")
  }

  func testIsVirtualDeviceTrueForVirtualFlag() {
    XCTAssertTrue(DisplayManager.isVirtualDevice(from: ["kCGDisplayIsVirtualDevice": true] as NSDictionary))
  }

  func testIsVirtualDeviceTrueForAirPlayFlag() {
    XCTAssertTrue(DisplayManager.isVirtualDevice(from: ["kCGDisplayIsAirPlay": true] as NSDictionary))
  }

  func testIsVirtualDeviceFalseWhenAbsentOrNilOrFalse() {
    XCTAssertFalse(DisplayManager.isVirtualDevice(from: nil))
    XCTAssertFalse(DisplayManager.isVirtualDevice(from: [:] as NSDictionary))
    XCTAssertFalse(DisplayManager.isVirtualDevice(from: ["kCGDisplayIsVirtualDevice": false] as NSDictionary))
  }

  func testIdBasedWrappersDelegateThroughProvider() {
    let virtualDisplay = StubInfoProvider(info: ["DisplayProductName": ["en_US": "Virtual Display 16:9"]])
    let monitor = StubInfoProvider(info: ["DisplayProductName": ["en_US": "LG UltraFine"]])

    XCTAssertEqual(DisplayManager.getDisplayNameByID(displayID: 1, provider: virtualDisplay), "Virtual Display 16:9")
    XCTAssertTrue(DisplayManager.isManaged(displayID: 1, provider: virtualDisplay))
    XCTAssertFalse(DisplayManager.isManaged(displayID: 1, provider: monitor))
  }
}
