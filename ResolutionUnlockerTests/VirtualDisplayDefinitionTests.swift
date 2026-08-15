//
//  ResolutionUnlockerTests
//
//  Tests for VirtualDisplayDefinition's multiplier math. The convenience init derives
//  min/max multipliers from the aspect ratio, the step, and the enable16K pref.
//

import XCTest
@testable import ResolutionUnlocker

final class VirtualDisplayDefinitionTests: XCTestCase {
  private let enable16KKey = PrefKey.enable16K.rawValue
  private var savedEnable16K: Bool = false

  override func setUp() {
    super.setUp()
    // VirtualDisplayDefinition reads enable16K from the shared UserDefaults; capture and
    // force a known value so the multiplier math is deterministic.
    savedEnable16K = UserDefaults.standard.bool(forKey: enable16KKey)
    UserDefaults.standard.set(false, forKey: enable16KKey)
  }

  override func tearDown() {
    UserDefaults.standard.set(savedEnable16K, forKey: enable16KKey)
    super.tearDown()
  }

  func testMultiplierMathFor16By9WithDefaultCap() {
    // 8192 cap: min = max(ceil(720/32), ceil(720/18)) = max(23, 40) = 40
    //           max = min(floor(8192/32), floor(8192/18)) = min(256, 455) = 256
    let def = VirtualDisplayDefinition(16, 9, 2, [60], "16:9 (HD/4K/5K/6K)", false)
    XCTAssertEqual(def.minMultiplier, 40)
    XCTAssertEqual(def.maxMultiplier, 256)
  }

  func testEnable16KRaisesTheMaxMultiplier() {
    UserDefaults.standard.set(true, forKey: enable16KKey)
    // 16384 cap: max = min(floor(16384/32), floor(16384/18)) = min(512, 910) = 512
    let def = VirtualDisplayDefinition(16, 9, 2, [60], "16:9 (HD/4K/5K/6K)", false)
    XCTAssertEqual(def.maxMultiplier, 512)
  }

  func testDesignatedInitStoresFieldsVerbatim() {
    let def = VirtualDisplayDefinition(16, 9, 40, 256, 2, [60, 120], "Some description", true)
    XCTAssertEqual(def.aspectWidth, 16)
    XCTAssertEqual(def.aspectHeight, 9)
    XCTAssertEqual(def.minMultiplier, 40)
    XCTAssertEqual(def.maxMultiplier, 256)
    XCTAssertEqual(def.multiplierStep, 2)
    XCTAssertEqual(def.refreshRates, [60, 120])
    XCTAssertEqual(def.description, "Some description")
    XCTAssertTrue(def.addSeparatorAfter)
  }

  func testAddSeparatorAfterDefaultsToFalse() {
    let def = VirtualDisplayDefinition(16, 9, 2, [60], "16:9")
    XCTAssertFalse(def.addSeparatorAfter)
  }
}
