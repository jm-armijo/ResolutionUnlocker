//
//  ResolutionUnlockerTests
//
//  Tests for DisplayManager's pure string helper. The rest of DisplayManager
//  depends on private CoreGraphics/CoreDisplay APIs and is out of scope here.
//

import XCTest
@testable import ResolutionUnlocker

final class DisplayManagerTests: XCTestCase {
  func testNormalizedNameStripsParenthesesSpacesAndDigits() {
    XCTAssertEqual(DisplayManager.normalizedName("Dell (1) 27"), "Dell")
  }

  func testNormalizedNameRemovesAllWhitespace() {
    XCTAssertEqual(DisplayManager.normalizedName("LG UltraFine"), "LGUltraFine")
  }

  func testNormalizedNameLeavesPlainNameUnchanged() {
    XCTAssertEqual(DisplayManager.normalizedName("VirtualDisplay"), "VirtualDisplay")
  }

  func testNormalizedNameStripsEmbeddedDigits() {
    XCTAssertEqual(DisplayManager.normalizedName("Studio 5K"), "StudioK")
  }
}
