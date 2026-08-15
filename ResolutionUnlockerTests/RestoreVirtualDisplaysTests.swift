//
//  ResolutionUnlockerTests
//
//  Phase 1 — characterization of VirtualDisplayManager.restoreFromPrefs. It reads per-virtualDisplay
//  keys from prefs and rebuilds the virtualDisplays. This runs as an integration test (the hosted
//  app supplies the menu refresh the method currently triggers); it pins the restore
//  bookkeeping before that UI coupling is inverted.
//

import XCTest
@testable import ResolutionUnlocker

final class RestoreVirtualDisplaysTests: XCTestCase {
  private let defaults = UserDefaults.standard
  private let keys = ["numOfVirtualDisplays", "display1", "serial1", "isConnected1",
                      "associatedDisplayPrefsId1", "associatedDisplayName1"]
  private var savedDefaults: [String: Any?] = [:]

  override func setUp() {
    super.setUp()
    VirtualDisplayManager.definedDisplays = [:]
    VirtualDisplayManager.displayCounter = 0
    VirtualDisplayManager.updateDefinitions()
    savedDefaults = DefaultsSnapshot.capture(keys, from: defaults)
  }

  override func tearDown() {
    VirtualDisplayManager.definedDisplays = [:]
    VirtualDisplayManager.displayCounter = 0
    DefaultsSnapshot.restore(savedDefaults, to: defaults)
    super.tearDown()
  }

  func testRestoresADisconnectedVirtualDisplayWithItsStoredFields() {
    defaults.set(1, forKey: "numOfVirtualDisplays")
    defaults.set(10, forKey: "display1")
    defaults.set(0xAB, forKey: "serial1")
    defaults.set(false, forKey: "isConnected1")
    defaults.set("(Some@1)", forKey: "associatedDisplayPrefsId1")
    defaults.set("Some Display", forKey: "associatedDisplayName1")

    VirtualDisplayManager.restoreFromPrefs()

    XCTAssertEqual(VirtualDisplayManager.getCount(), 1)
    let virtualDisplay = VirtualDisplayManager.getAll().first
    XCTAssertEqual(virtualDisplay?.serialNum, 0xAB)
    XCTAssertEqual(VirtualDisplayManager.getDefinitionIdByNumber(1), 10)
    XCTAssertEqual(virtualDisplay?.associatedDisplayPrefsId, "(Some@1)")
    XCTAssertEqual(virtualDisplay?.associatedDisplayName, "Some Display")
    XCTAssertEqual(virtualDisplay?.isConnected, false)
  }

  func testRestoresNothingWhenCountIsZero() {
    defaults.set(0, forKey: "numOfVirtualDisplays")
    VirtualDisplayManager.restoreFromPrefs()
    XCTAssertEqual(VirtualDisplayManager.getCount(), 0)
  }

  // Phase 2 — with the UI coupling inverted, restore is testable in isolation via an
  // injected refresher, and we can assert it triggers exactly one menu repopulate.
  func testRestoreRefreshesTheMenuThroughTheInjectedRefresher() {
    let previousRefresher = VirtualDisplayManager.menuRefresher
    let fake = FakeMenuRefresher()
    VirtualDisplayManager.menuRefresher = fake
    defer { VirtualDisplayManager.menuRefresher = previousRefresher }

    defaults.set(1, forKey: "numOfVirtualDisplays")
    defaults.set(10, forKey: "display1")
    defaults.set(0xAB, forKey: "serial1")
    defaults.set(false, forKey: "isConnected1")
    defaults.set("", forKey: "associatedDisplayPrefsId1")
    defaults.set("", forKey: "associatedDisplayName1")

    VirtualDisplayManager.restoreFromPrefs()

    XCTAssertEqual(VirtualDisplayManager.getCount(), 1)
    XCTAssertEqual(fake.populateCount, 1)
  }
}

private final class FakeMenuRefresher: AppMenuRefreshing {
  var populateCount = 0
  func populateAppMenu() { populateCount += 1 }
}
