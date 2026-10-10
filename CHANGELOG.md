## 0.1.3

* Documents what iOS does at run time, in a section of its own. Once access is
  allowed, the confirmation does not come back when the app is started again.
  Leaving the app while the confirmation is open closes it unanswered, and the
  taps that follow report `tapWithoutAuthorization` without showing it again,
  so the button appears to do nothing until the app is started once more.
* Documents that Precise Location, turned off for the app in the system
  settings, makes the system button report an approximate position, with
  `isPrecise` false and no altitude, whether access was granted before or
  after the setting changed.
* Documents that a tap reports the position the system determined for it,
  which can be one the system already had, so two taps a moment apart can
  report the same position with the same timestamp.
* Says that the placement rules decide whether the system grants access and do
  not apply to access the app already holds: while an earlier tap still grants
  it, a tap on a clipped, faded, scaled or covered button reports a position.

## 0.1.2

* Describes the package as the button that the Google Play location policy
  requires, rather than as required itself: the rules apply to apps that
  target Android 17 and need precise location only for one-time actions.
* Adds a Quick start that shows the whole integration, ahead of the example
  that handles every result.
* Documents the package next to `geolocator` and `permission_handler`: the
  app's own `ACCESS_FINE_LOCATION` declaration stays the only one in the
  merged manifest, the `onlyForLocationButton` flag keeps other packages from
  requesting precise location, and access granted through the system button is
  visible to every package for as long as it lasts.

## 0.1.1

* Documents the `post_install` hook that an app needs in `ios/Podfile` to build
  with Xcode 27, which does not build for the iOS 13 that the Flutter pod still
  targets.

## 0.1.0

* Initial release of `OneTapLocationButton`, backed by `CLLocationButton` on
  iOS and the system location button on Android 17, with a fallback button
  that uses the permission dialog on Android 7 to 16.
* `OneTapLocationButton.checkAvailability()` reports which button the widget
  shows on the device, and whether the app restricts precise location to the
  system button.
* `package:one_tap_location/testing.dart` provides `FakeOneTapLocation`, which
  lets widget tests find, tap and answer the button.
