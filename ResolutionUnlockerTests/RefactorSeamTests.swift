//
//  ResolutionUnlockerTests
//
//  Phase 2 — unit tests against the seams introduced by the DI refactor. These drive
//  the extracted pure logic directly (no private APIs, no real display) and assert the
//  behavior that must hold both before and after the bug fixes. The 0-mode and
//  multi-refresh-rate edge cases are deliberately left for Phase 3.
//

import XCTest
@testable import ResolutionUnlocker

final class MakeResolutionsTests: XCTestCase {
  private func fakeInfo(density: @escaping (Int) -> Float = { _ in 1 }) -> (Int) -> DisplayModeInfo {
    { index in
      DisplayModeInfo(
        modeNumber: UInt32(index),
        width: UInt32(1000 + index),
        height: UInt32(500 + index),
        depth: 32,
        refreshRate: 60,
        density: density(index)
      )
    }
  }

  func testMapsEveryModeAndKeysByIndex() {
    let resolutions = Display.makeResolutions(count: 3, currentIndex: 1, info: fakeInfo())
    XCTAssertEqual(Set(resolutions.keys), [0, 1, 2])
    XCTAssertEqual(resolutions[2]?.width, 1002)
    XCTAssertEqual(resolutions[2]?.height, 502)
    XCTAssertEqual(resolutions[0]?.bitDepth, 32)
    XCTAssertEqual(resolutions[0]?.refreshRate, 60)
  }

  func testFlagsOnlyTheCurrentIndexActive() {
    let resolutions = Display.makeResolutions(count: 3, currentIndex: 1, info: fakeInfo())
    XCTAssertEqual(resolutions.values.filter { $0.isActive }.count, 1)
    XCTAssertTrue(resolutions[1]?.isActive ?? false)
    XCTAssertFalse(resolutions[0]?.isActive ?? true)
    XCTAssertFalse(resolutions[2]?.isActive ?? true)
  }

  func testHiDPIDerivedFromDensityGreaterThanOne() {
    let resolutions = Display.makeResolutions(count: 2, currentIndex: 0,
                                              info: fakeInfo(density: { $0 == 1 ? 2 : 1 }))
    XCTAssertEqual(resolutions[0]?.hiDPI, false)
    XCTAssertEqual(resolutions[1]?.hiDPI, true)
  }
}

final class MakeModeSpecsTests: XCTestCase {
  func testSingleRefreshRateProducesOneSpecPerMultiplier() {
    // Fixed multiplier range 40...44 → 5 multipliers, independent of enable16K.
    let definition = VirtualDisplayDefinition(16, 9, 40, 44, 2, [60], "test", false)
    let specs = VirtualDisplay.makeModeSpecs(for: definition)

    XCTAssertEqual(specs.count, 5)
    // multiplier 40: 16*40*2 = 1280 wide, 9*40*2 = 720 high
    XCTAssertEqual(specs.first, VirtualDisplay.ModeSpec(width: 1280, height: 720, refreshRate: 60))
    // multiplier 44: 16*44*2 = 1408 wide, 9*44*2 = 792 high
    XCTAssertEqual(specs.last, VirtualDisplay.ModeSpec(width: 1408, height: 792, refreshRate: 60))
    XCTAssertTrue(specs.allSatisfy { $0.refreshRate == 60 })
  }
}
