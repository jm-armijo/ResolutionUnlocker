//
//  ResolutionUnlockerTests
//
//  Phase 3 — tests that reproduce the two bugs, written before the fixes. They exercise
//  the pure seams extracted in Phase 2:
//    * makeResolutions with a zero mode count used to trap on `0 ... count - 1`.
//    * makeModeSpecs with multiple refresh rates used to overwrite, keeping only the
//      last rate per multiplier.
//

import XCTest
@testable import ResolutionUnlocker

final class BugFixTests: XCTestCase {
  // Bug A: a display reporting zero modes must yield an empty result, not crash.
  func testZeroModeCountProducesEmptyResolutionsWithoutCrashing() {
    let resolutions = Display.makeResolutions(count: 0, currentIndex: 0) { _ in
      XCTFail("info must not be queried when there are no modes")
      return DisplayModeInfo(modeNumber: 0, width: 0, height: 0, depth: 0, refreshRate: 0, density: 0)
    }
    XCTAssertTrue(resolutions.isEmpty)
  }

  // Bug B: with multiple refresh rates, every multiplier must appear once per rate.
  func testMultipleRefreshRatesProduceOneSpecPerMultiplierPerRate() {
    let definition = VirtualDisplayDefinition(16, 9, 40, 44, 2, [60, 120], "test", false)
    let specs = VirtualDisplay.makeModeSpecs(for: definition)

    // 5 multipliers (40...44) × 2 refresh rates.
    XCTAssertEqual(specs.count, 10)

    // The smallest multiplier (40) → 1280x720 must exist at both refresh rates.
    let mult40 = specs.filter { $0.width == 1280 && $0.height == 720 }
    XCTAssertEqual(Set(mult40.map { $0.refreshRate }), [60, 120])
  }
}
