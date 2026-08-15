//
//  ResolutionUnlockerTests
//
//  Shared test helpers.
//
//  NOTE: these tests run hosted inside the ResolutionUnlocker app, so `UserDefaults.standard`
//  is the app's *real* preferences domain (com.jm-armijo.ResolutionUnlocker). Any test that
//  writes prefs must capture the prior values and restore them afterwards so a real
//  saved virtualDisplay configuration is never clobbered.
//

import Foundation

enum DefaultsSnapshot {
  /// Capture the current value (or absence) of each key.
  static func capture(_ keys: [String], from defaults: UserDefaults) -> [String: Any?] {
    var snapshot: [String: Any?] = [:]
    for key in keys {
      snapshot[key] = defaults.object(forKey: key)
    }
    return snapshot
  }

  /// Restore captured values; keys that were absent are removed again.
  static func restore(_ snapshot: [String: Any?], to defaults: UserDefaults) {
    for (key, value) in snapshot {
      if let value = value {
        defaults.set(value, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }
}
