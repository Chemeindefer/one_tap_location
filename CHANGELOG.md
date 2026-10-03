## 0.1.0

* Initial release of `OneTapLocationButton`, backed by `CLLocationButton` on
  iOS and the system location button on Android 17, with a fallback button
  that uses the permission dialog on Android 7 to 16.
* `OneTapLocationButton.checkAvailability()` reports which button the widget
  shows on the device, and whether the app restricts precise location to the
  system button.
* `package:one_tap_location/testing.dart` provides `FakeOneTapLocation`, which
  lets widget tests find, tap and answer the button.
