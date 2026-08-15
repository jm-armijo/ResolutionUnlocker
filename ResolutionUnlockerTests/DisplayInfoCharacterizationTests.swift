//
//  ResolutionUnlockerTests
//
//  Phase 1 — characterization of DisplayManager's CoreDisplay-backed classification
//  against the real main display. Pins current behavior before the DI refactor of the
//  info-dictionary access.
//

import XCTest
import CoreGraphics
@testable import ResolutionUnlocker

final class DisplayInfoCharacterizationTests: XCTestCase {
  func testMainDisplayNameIsNonEmpty() {
    let name = DisplayManager.getDisplayNameByID(displayID: CGMainDisplayID())
    XCTAssertFalse(name.isEmpty)
  }

  func testMainDisplayIsNotVirtual() {
    XCTAssertFalse(DisplayManager.isVirtual(displayID: CGMainDisplayID()))
  }

  func testMainDisplayIsNotAVirtualDisplay() {
    XCTAssertFalse(DisplayManager.isManaged(displayID: CGMainDisplayID()))
  }
}
