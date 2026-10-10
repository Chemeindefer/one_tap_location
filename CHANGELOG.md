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
