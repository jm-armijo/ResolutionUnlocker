//
//  ResolutionUnlockerTests
//
//  Characterization tests for PrefKey raw values. These strings are used directly
//  as UserDefaults keys (and, for SUEnableAutomaticChecks, are read by Sparkle),
//  so their exact spelling is part of the app's contract.
//

import XCTest
@testable import ResolutionUnlocker

final class PrefKeyTests: XCTestCase {
  func testSparkleAutomaticChecksKeyMatchesSparkleContract() {
    // Sparkle reads "SUEnableAutomaticChecks" from UserDefaults for
    // automaticallyChecksForUpdates; the enum case must map to that exact string.
    XCTAssertEqual(PrefKey.SUEnableAutomaticChecks.rawValue, "SUEnableAutomaticChecks")
  }

  func testPerVirtualDisplayKeysHaveExpectedRawValues() {
    XCTAssertEqual(PrefKey.display.rawValue, "display")
    XCTAssertEqual(PrefKey.serial.rawValue, "serial")
    XCTAssertEqual(PrefKey.isConnected.rawValue, "isConnected")
    XCTAssertEqual(PrefKey.associatedDisplayPrefsId.rawValue, "associatedDisplayPrefsId")
    XCTAssertEqual(PrefKey.associatedDisplayName.rawValue, "associatedDisplayName")
  }

  func testGeneralKeysHaveExpectedRawValues() {
    XCTAssertEqual(PrefKey.appAlreadyLaunched.rawValue, "appAlreadyLaunched")
    XCTAssertEqual(PrefKey.numOfVirtualDisplays.rawValue, "numOfVirtualDisplays")
    XCTAssertEqual(PrefKey.hideMenuIcon.rawValue, "hideMenuIcon")
    XCTAssertEqual(PrefKey.enable16K.rawValue, "enable16K")
    XCTAssertEqual(PrefKey.alwaysUseSerialForDisplayPrefsId.rawValue, "alwaysUseSerialForDisplayPrefsId")
  }
}
