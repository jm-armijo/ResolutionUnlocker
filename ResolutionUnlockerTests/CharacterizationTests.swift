//
//  ResolutionUnlockerTests
//
//  Phase 1 — characterization tests. These are *integration* tests: they drive the
//  real code paths through the private CoreGraphics/CGVirtualDisplay APIs and pin the
//  current observable behavior of the two sites that are about to be refactored, so
//  the refactor can be proven regression-free WITHOUT changing these tests.
//
//  They intentionally do not assert the "correct" (post-fix) behavior — they lock in
//  what the code does today, bugs and all.
//

import XCTest
import CoreGraphics
@testable import ResolutionUnlocker

final class DisplayResolutionCharacterizationTests: XCTestCase {
  // Exercises Display.updateResolutions() against the real main display. This is the
  // method whose `0 ... count - 1` loop is the crash bug; here we only pin the normal
  // (non-empty) path that a real display always hits.
  func testMainDisplayResolutionsArePopulatedAndSelfConsistent() throws {
    let mainID = CGMainDisplayID()
    let display = Display(mainID, name: "Main", vendorNumber: nil, modelNumber: nil, serialNumber: nil)

    XCTAssertFalse(display.resolutions.isEmpty, "A real display always exposes at least one mode")

    // Exactly one mode is flagged active — the current one.
    let activeResolutions = display.resolutions.values.filter { $0.isActive }
    XCTAssertEqual(activeResolutions.count, 1)

    // The active mode drives the cached width/height and the currentResolution key.
    XCTAssertGreaterThan(display.width, 0)
    XCTAssertGreaterThan(display.height, 0)
    XCTAssertNotNil(display.resolutions[display.currentResolution])
    XCTAssertEqual(display.pixelWidth, display.width * (display.isHiDPI ? 2 : 1))
    XCTAssertEqual(display.pixelHeight, display.height * (display.isHiDPI ? 2 : 1))
  }
}

final class VirtualDisplayModeCharacterizationTests: XCTestCase {
  // Exercises VirtualDisplay.createCGVirtualDisplay(), which contains the modes-array bug. With a
  // single refresh rate the current behavior is "one mode per multiplier", which we pin
  // here. A small multiplier range keeps the throwaway display cheap; it is removed when
  // the returned CGVirtualDisplay deallocates at the end of the test.
  func testCreatedVirtualDisplayHasOneModePerMultiplierForSingleRefreshRate() throws {
    // Designated init with a fixed, small multiplier range so the assertion does not
    // depend on the enable16K preference.
    let definition = VirtualDisplayDefinition(16, 9, 40, 44, 2, [60], "16:9 characterization", false)
    let expectedModeCount = definition.maxMultiplier - definition.minMultiplier + 1 // 5

    let virtualDisplay = try XCTUnwrap(
      VirtualDisplay.createCGVirtualDisplay(definition, name: "Virtual Display Characterization", serialNum: 0x7E57),
      "Expected the virtual display to be created on this machine"
    )

    XCTAssertNotEqual(virtualDisplay.displayID, 0)
    XCTAssertEqual(virtualDisplay.modes.count, expectedModeCount)
  }
}
