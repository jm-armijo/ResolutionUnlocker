//
//  ResolutionUnlockerTests
//
//  Tests for VirtualDisplay's pure logic. Every VirtualDisplay is built with doConnect: false so the
//  private CGVirtualDisplay APIs are never touched.
//

import XCTest
@testable import ResolutionUnlocker

final class VirtualDisplayTests: XCTestCase {
  private func makeDefinition(_ description: String = "16:9 (HD/4K/5K/6K)") -> VirtualDisplayDefinition {
    VirtualDisplayDefinition(16, 9, 40, 256, 2, [60], description, false)
  }

  private func makeVirtualDisplay(serialNum: UInt32, description: String = "16:9 (HD/4K/5K/6K)") -> VirtualDisplay {
    VirtualDisplay(definition: makeDefinition(description), serialNum: serialNum, doConnect: false)
  }

  func testExplicitSerialNumberIsStored() {
    let virtualDisplay = makeVirtualDisplay(serialNum: 0xAB)
    XCTAssertEqual(virtualDisplay.serialNum, 0xAB)
  }

  func testGetSerialNumberFormatsAsUppercaseHex() {
    XCTAssertEqual(makeVirtualDisplay(serialNum: 0x0F).getSerialNumber(), "0F")
    XCTAssertEqual(makeVirtualDisplay(serialNum: 0xAB).getSerialNumber(), "AB")
    XCTAssertEqual(makeVirtualDisplay(serialNum: 0x1234).getSerialNumber(), "1234")
  }

  func testGetNameUsesFirstWordOfDescription() {
    XCTAssertEqual(makeVirtualDisplay(serialNum: 1, description: "16:9 (HD/4K/5K/6K)").getName(), "Virtual Display 16:9")
    XCTAssertEqual(makeVirtualDisplay(serialNum: 1, description: "1:1 (Square)").getName(), "Virtual Display 1:1")
  }

  func testGetMenuItemTitleCombinesFirstWordAndHexSerial() {
    let virtualDisplay = makeVirtualDisplay(serialNum: 0xAB, description: "16:9 (HD/4K/5K/6K)")
    XCTAssertEqual(virtualDisplay.getMenuItemTitle(), "16:9 - #AB")
  }

  func testAssociationStateStartsEmptyAndCanBeCleared() {
    let virtualDisplay = makeVirtualDisplay(serialNum: 1)
    XCTAssertFalse(virtualDisplay.hasAssociatedDisplay())

    virtualDisplay.associatedDisplayPrefsId = "(SomeDisplay@123)"
    virtualDisplay.associatedDisplayName = "Some Display"
    XCTAssertTrue(virtualDisplay.hasAssociatedDisplay())

    virtualDisplay.disassociateDisplay()
    XCTAssertFalse(virtualDisplay.hasAssociatedDisplay())
    XCTAssertEqual(virtualDisplay.associatedDisplayPrefsId, "")
    XCTAssertEqual(virtualDisplay.associatedDisplayName, "")
  }

  func testEqualityIsBySerialNumber() {
    XCTAssertEqual(makeVirtualDisplay(serialNum: 42), makeVirtualDisplay(serialNum: 42))
    XCTAssertNotEqual(makeVirtualDisplay(serialNum: 42), makeVirtualDisplay(serialNum: 43))
  }

  func testStartsDisconnectedWhenDoConnectIsFalse() {
    XCTAssertFalse(makeVirtualDisplay(serialNum: 1).isConnected)
  }
}
