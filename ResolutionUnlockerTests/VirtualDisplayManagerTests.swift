//
//  ResolutionUnlockerTests
//
//  Tests for VirtualDisplayManager's bookkeeping (the ever-increasing counter, the
//  definedDisplays map, and prefs serialization). All virtualDisplays are created with
//  doConnect: false so no private display APIs are exercised.
//

import XCTest
@testable import ResolutionUnlocker

final class VirtualDisplayManagerTests: XCTestCase {
  private let defaults = UserDefaults.standard
  private let touchedKeys = ["numOfVirtualDisplays", "display1", "serial1", "isConnected1",
                             "associatedDisplayPrefsId1", "associatedDisplayName1"]

  private var savedDefaults: [String: Any?] = [:]

  override func setUp() {
    super.setUp()
    // VirtualDisplayManager keeps global static state; reset it for isolation.
    VirtualDisplayManager.definedDisplays = [:]
    VirtualDisplayManager.displayCounter = 0
    VirtualDisplayManager.updateDefinitions()
    // Preserve the user's real prefs for these keys, then clear for a clean slate.
    savedDefaults = DefaultsSnapshot.capture(touchedKeys, from: defaults)
    touchedKeys.forEach { defaults.removeObject(forKey: $0) }
  }

  override func tearDown() {
    VirtualDisplayManager.definedDisplays = [:]
    VirtualDisplayManager.displayCounter = 0
    DefaultsSnapshot.restore(savedDefaults, to: defaults)
    super.tearDown()
  }

  private func def() -> VirtualDisplayDefinition {
    VirtualDisplayManager.definitions[10]!
  }

  func testCreateVirtualDisplayIncrementsCounterAndStores() {
    let first = VirtualDisplayManager.create(def(), doConnect: false)
    let second = VirtualDisplayManager.create(def(), doConnect: false)
    XCTAssertEqual(first, 1)
    XCTAssertEqual(second, 2)
    XCTAssertEqual(VirtualDisplayManager.displayCounter, 2)
    XCTAssertEqual(VirtualDisplayManager.getCount(), 2)
    XCTAssertEqual(VirtualDisplayManager.getAll().count, 2)
  }

  func testCreateVirtualDisplayByUnknownDefinitionIdReturnsNil() {
    XCTAssertNil(VirtualDisplayManager.createByDefinitionId(9999, doConnect: false))
    XCTAssertEqual(VirtualDisplayManager.getCount(), 0)
  }

  func testCreateVirtualDisplayByDefinitionIdRecordsDefinitionId() {
    let number = VirtualDisplayManager.createByDefinitionId(10, doConnect: false)
    XCTAssertNotNil(number)
    XCTAssertEqual(VirtualDisplayManager.getDefinitionIdByNumber(number!), 10)
  }

  func testGetVirtualDisplayByNumberReturnsNilForUnknown() {
    let number = VirtualDisplayManager.create(def(), doConnect: false)
    XCTAssertNotNil(VirtualDisplayManager.getByNumber(number))
    XCTAssertNil(VirtualDisplayManager.getByNumber(999))
  }

  func testDiscardVirtualDisplayByNumberRemovesOnlyThatVirtualDisplay() {
    let a = VirtualDisplayManager.create(def(), doConnect: false)
    _ = VirtualDisplayManager.create(def(), doConnect: false)
    VirtualDisplayManager.discardByNumber(a)
    XCTAssertNil(VirtualDisplayManager.getByNumber(a))
    XCTAssertEqual(VirtualDisplayManager.getCount(), 1)
  }

  func testDiscardAllVirtualDisplaysClearsMapAndResetsCounter() {
    _ = VirtualDisplayManager.create(def(), doConnect: false)
    _ = VirtualDisplayManager.create(def(), doConnect: false)
    VirtualDisplayManager.discardAll()
    XCTAssertEqual(VirtualDisplayManager.getCount(), 0)
    XCTAssertEqual(VirtualDisplayManager.displayCounter, 0)
  }

  func testGetVirtualDisplayByDisplayIdMatchesOnDisplayIdentifier() {
    let number = VirtualDisplayManager.create(def(), doConnect: false)
    let virtualDisplay = VirtualDisplayManager.getByNumber(number)!
    virtualDisplay.displayIdentifier = 42
    XCTAssertTrue(VirtualDisplayManager.getByDisplayId(42) === virtualDisplay)
    XCTAssertNil(VirtualDisplayManager.getByDisplayId(99))
  }

  func testUpdateVirtualDisplayDefinitionsPopulatesExpectedKeys() {
    let expected: Set<Int> = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100,
                              110, 120, 130, 140, 210, 220, 350, 360, 370]
    XCTAssertEqual(Set(VirtualDisplayManager.definitions.keys), expected)
  }

  func testStoreVirtualDisplaysToPrefsWritesPerVirtualDisplayKeys() {
    _ = VirtualDisplayManager.create(def(), definitionId: 10, serialNum: 0xAB, doConnect: false)
    VirtualDisplayManager.storeToPrefs()

    XCTAssertEqual(defaults.integer(forKey: "numOfVirtualDisplays"), 1)
    XCTAssertEqual(defaults.integer(forKey: "display1"), 10)
    XCTAssertEqual(defaults.integer(forKey: "serial1"), 0xAB)
    XCTAssertFalse(defaults.bool(forKey: "isConnected1"))
    XCTAssertEqual(defaults.string(forKey: "associatedDisplayPrefsId1"), "")
  }

  func testStoreVirtualDisplaysToPrefsWithNoVirtualDisplaysWritesZeroCount() {
    VirtualDisplayManager.storeToPrefs()
    XCTAssertEqual(defaults.integer(forKey: "numOfVirtualDisplays"), 0)
  }
}
