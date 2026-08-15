//
//  ResolutionUnlocker
//
//  Created by @waydabber
//

enum PrefKey: String {
  // Virtual display specific
  case display
  case serial
  case isConnected
  case associatedDisplayPrefsId
  case associatedDisplayName

  // General
  case appAlreadyLaunched
  case numOfVirtualDisplays
  case buildNumber
  case startAtLogin
  case hideMenuIcon
  case reconnectAfterSleep
  case disableTempSleep
  case SUEnableAutomaticChecks
  case isBetaChannel
  case enable16K
  case hideLowResolutionOption
  case alwaysUseSerialForDisplayPrefsId

  // Not used
  case enableSliderSnap
  case showTickMarks
}
