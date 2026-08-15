//
//  ResolutionUnlockerTests
//
//  Tests unlocked by the DI seam introduced in the earlier refactor. A fake mode
//  provider lets us construct Display objects and drive DisplayManager logic
//  deterministically, with no real hardware and no private-API calls.
//

import XCTest
import CoreGraphics
@testable import ResolutionUnlocker

/// Deterministic stand-in for SystemDisplayModeProvider.
struct FakeDisplayModeProvider: DisplayModeProviding {
  var count: Int
  var currentIndex: Int
  var modes: [DisplayModeInfo]

  func modeCount(for _: CGDirectDisplayID) -> Int { count }
  func currentModeIndex(for _: CGDirectDisplayID) -> Int { currentIndex }
  func modeInfo(for _: CGDirectDisplayID, index: Int) -> DisplayModeInfo { modes[index] }

  /// A provider with no modes — enough to build a Display whose resolution set is empty.
  static var empty: FakeDisplayModeProvider { .init(count: 0, currentIndex: 0, modes: []) }
}

final class DisplayInjectionTests: XCTestCase {
  // Exercises the updateResolutions *method* (provider calls + active-field derivation)
  // deterministically, which previously was only reachable via a real display.
  func testUpdateResolutionsDerivesActiveFieldsFromInjectedProvider() {
    let provider = FakeDisplayModeProvider(count: 2, currentIndex: 1, modes: [
      DisplayModeInfo(modeNumber: 0, width: 1920, height: 1080, depth: 32, refreshRate: 60, density: 1),
      DisplayModeInfo(modeNumber: 1, width: 2560, height: 1440, depth: 32, refreshRate: 60, density: 2),
    ])

    let display = Display(1, name: "Fake", vendorNumber: nil, modelNumber: nil, serialNumber: nil, modeProvider: provider)

    XCTAssertEqual(display.resolutions.count, 2)
    XCTAssertEqual(display.currentResolution, 1)
    XCTAssertEqual(display.width, 2560)
    XCTAssertEqual(display.height, 1440)
    XCTAssertTrue(display.isHiDPI)
    XCTAssertEqual(display.pixelWidth, 5120)
    XCTAssertEqual(display.pixelHeight, 2880)
  }

  func testMakeResolutionsWithCurrentIndexOutOfRangeMarksNoModeActive() {
    let resolutions = Display.makeResolutions(count: 3, currentIndex: 99) { index in
      DisplayModeInfo(modeNumber: UInt32(index), width: 100, height: 100, depth: 32, refreshRate: 60, density: 1)
    }
    XCTAssertEqual(resolutions.count, 3)
    XCTAssertTrue(resolutions.values.allSatisfy { !$0.isActive })
  }

  func testMakeResolutionsWithNegativeCountIsEmpty() {
    let resolutions = Display.makeResolutions(count: -1, currentIndex: 0) { _ in
      XCTFail("info must not be queried for a negative count")
      return DisplayModeInfo(modeNumber: 0, width: 0, height: 0, depth: 0, refreshRate: 0, density: 0)
    }
    XCTAssertTrue(resolutions.isEmpty)
  }
}

final class DisplayCounterSuffixTests: XCTestCase {
  override func setUp() {
    super.setUp()
    DisplayManager.clearDisplays()
  }

  override func tearDown() {
    DisplayManager.clearDisplays()
    super.tearDown()
  }

  private func makeDisplay(_ id: CGDirectDisplayID, _ name: String) -> Display {
    Display(id, name: name, vendorNumber: nil, modelNumber: nil, serialNumber: nil, modeProvider: FakeDisplayModeProvider.empty)
  }

  func testDuplicateNamesGetNumericSuffixesAndUniqueNamesAreUntouched() {
    DisplayManager.addDisplay(display: makeDisplay(1, "Dell"))
    DisplayManager.addDisplay(display: makeDisplay(2, "Dell"))
    DisplayManager.addDisplay(display: makeDisplay(3, "LG"))

    DisplayManager.addDisplayCounterSuffixes()

    // Which duplicate becomes (1) vs (2) depends on dictionary order, so assert the set.
    let names = Set(DisplayManager.getDisplays().map { $0.name })
    XCTAssertEqual(names, ["Dell (1)", "Dell (2)", "LG"])
  }

  func testSuffixingIsStableWhenNamesAreAlreadyUnique() {
    DisplayManager.addDisplay(display: makeDisplay(1, "Dell"))
    DisplayManager.addDisplay(display: makeDisplay(2, "LG"))

    // Running twice must not double-suffix, since after the first pass names are unique.
    DisplayManager.addDisplayCounterSuffixes()
    DisplayManager.addDisplayCounterSuffixes()

    let names = Set(DisplayManager.getDisplays().map { $0.name })
    XCTAssertEqual(names, ["Dell", "LG"])
  }
}
