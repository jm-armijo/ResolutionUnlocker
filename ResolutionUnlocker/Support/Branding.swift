//
//  ResolutionUnlocker
//
//  Created by @waydabber
//

// Central place for user-facing product/branding strings. Change a value here to rebrand the
// whole app without hunting through the codebase.
enum Branding {
  // Product name, shown in menus, About/Reset dialogs and window copy.
  static let appName = "ResolutionUnlocker"

  // User-facing noun for the virtual display object this app creates and manages.
  // IMPORTANT: this string is also embedded in every created display's name (see
  // VirtualDisplay.getName) and is the marker DisplayManager.isManaged uses to recognise the
  // app's own displays. Keeping both sides driven by this single constant means the display
  // name and the detector can never drift apart.
  static let displayNoun = "Virtual Display"
  static let displayNounPlural = "Virtual Displays"
}
