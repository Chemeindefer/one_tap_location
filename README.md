# one_tap_location

![One tap. One fix. Consent drawn by the system. The platform location buttons
for Flutter: iOS CLLocationButton, the Android 17 system button, and a fallback
for Android 7 to 16.](doc/cover.png)

A Flutter widget that gets the user's location with a single tap on the
system location button.

The system draws the button and asks for consent, so the app shows no
permission dialog of its own. The first tap shows a system confirmation; once
the user allows access, later taps grant one-time access right away.

| Platform | Button |
| --- | --- |
| iOS 15+ | `CLLocationButton` |
| Android 17+ | The system location button |
| Android 7–16 | A fallback button that asks with the permission dialog |

On other platforms the widget renders nothing and reports no results. In
iPhone and iPad apps on Apple Vision Pro, `CLLocationButton` does not respond to
taps; with visionOS 26.1 or later, the widget renders nothing there either. Such
apps need their own way to get a location; see [Availability](#availability).

Each tap reports one position. The widget does not track the location, work in
the background or locate without a tap.

Google Play has announced that apps that target Android 17 or later and need
precise location only for one-time actions that the user starts, such as
filling in an address or searching nearby, will have to use the system location
button and restrict precise location to it. See
[Google Play location policy](#google-play-location-policy) for the date and
the manifest changes.

## Quick start

Declare the location permissions in
`android/app/src/main/AndroidManifest.xml`, and a usage description in
`ios/Runner/Info.plist`; iOS also needs its deployment target at 15.0. See
[Android setup](#android-setup) and [iOS setup](#ios-setup).

Then show the button and read the position from the result:

```dart
OneTapLocationButton(
  onResult: (OneTapLocationResult result) {
    if (result case OneTapLocationGranted(:final position)) {
      setState(() {
        _coordinates = '${position.latitude}, ${position.longitude}';
      });
    }
  },
)
```

That is the whole integration: the system draws the button, asks for consent
and reports the outcome. [Usage](#usage) handles the two outcomes this example
ignores, and [Placement](#placement) covers where the button can be shown.

## Usage

```dart
class _AddressFormState extends State<AddressForm> {
  final OneTapLocationController _controller = OneTapLocationController();
  late final StreamSubscription<OneTapLocationDiagnostic>
  _diagnosticSubscription;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _diagnosticSubscription = _controller.diagnostics.listen((diagnostic) {
      setState(() => _status = 'Location access was not granted.');
    });
  }

  @override
  void dispose() {
    _diagnosticSubscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleResult(OneTapLocationResult result) {
    setState(() {
      _status = switch (result) {
        OneTapLocationGranted(:final position) =>
          '${position.latitude}, ${position.longitude}',
        OneTapLocationDenied() => 'Location access was denied.',
        OneTapLocationFailed(:final exception)
            when exception.code ==
                OneTapLocationErrorCode.locationServicesDisabled =>
          'Turn on location services to share your location.',
        OneTapLocationFailed() => 'The location could not be determined.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        OneTapLocationButton(controller: _controller, onResult: _handleResult),
        Text(_status),
      ],
    );
  }
}
```

A result is reported only once the outcome is known. While the position is
being determined after access was granted, `OneTapLocationController.isLocating`
is true. When location services are turned off on the device, the result is
`OneTapLocationFailed` with `OneTapLocationErrorCode.locationServicesDisabled`,
so the app can ask the user to turn them on; neither platform shows a prompt
of its own for this case.

`position.altitude` is the altitude above mean sea level. It is null when
`position.isPrecise` is false, on Android 13 and earlier, and whenever no valid
altitude was determined for the position.

## Availability

`OneTapLocationButton.checkAvailability()` tells which button the widget shows
on the device:

| Device | `buttonType` |
| --- | --- |
| iOS | `system` |
| iPhone and iPad apps on Apple Vision Pro with visionOS 26.1 or later | `none` |
| Android 17 or later, where the system provides the location button | `system` |
| Android 7–16, and later versions whose system does not provide it | `fallback` |
| Web and other platforms | `none` |

Earlier versions of visionOS, and apps built with Xcode earlier than 26.1,
cannot detect that the app runs on Apple Vision Pro, so there `buttonType` is
`system` although the button does not respond; apps can turn off their
availability on Apple Vision Pro in App Store Connect.

`isPreciseLocationRestrictedToSystemButton` is true on Android 17 and later
when the app declares `ACCESS_FINE_LOCATION` with the `onlyForLocationButton`
flag. The flag restricts precise location to the system location button, so
the permission dialog that the fallback button shows offers approximate
location only:

```dart
final OneTapLocationAvailability availability =
    await OneTapLocationButton.checkAvailability();
if (availability.buttonType == OneTapLocationButtonType.fallback &&
    availability.isPreciseLocationRestrictedToSystemButton) {
  // Precise location is not available on this device.
}
```

The availability does not change while the app runs, and the widget uses the
same answer to choose its button. It describes the device, not whether the
button can be shown: where the system fails to open the location button, the
widget reports the error to `FlutterError.onError` and shows nothing.

## Size

On iOS, the widget takes the size that the system requires for its label,
icon and font size. The system ignores taps on a smaller button, so the parent
must allow at least that size in both directions; in debug builds, a parent
that imposes a smaller size, such as a `SizedBox` 48 pixels tall, fails an
assertion.

On Android, the widget fills the width of its parent and is 48 logical pixels
tall, unless the parent requires another height between 48 and 136. The
system draws its label inside that area and cuts the label off when the area
is too narrow, so leave room for the label in every language the app
supports. With `AndroidLocationButtonLabel.none`, the button is a 48 × 48
square, unless the parent requires a larger size. The fallback button on
Android 7–16 has the same size.

## Placement

The system accepts a tap only while the button is fully visible.

On iOS, the system ignores the tap, without reporting an error, when the
button is:

* partly scrolled out of view or clipped,
* translucent, including during a fade transition,
* scaled down,
* smaller than the size the system requires,
* covered by other content.

When a tap does not grant access within a few seconds, the controller reports
`OneTapLocationDiagnostic.tapWithoutAuthorization`. If access is granted
later, the result is still reported, unless another button was tapped in the
meantime.

These rules decide whether the system grants access. They do not apply to
access the app already holds: while an earlier tap still grants it, a tap on a
button in any of those states reports a position.

On Android 17 and later, the system draws the button above all Flutter
content, and Flutter cannot clip, fade or cover it. The widget therefore hides
the button while:

* its route is not the current route, or a route transition runs,
* an ancestor clips it, including a scroll view that has scrolled it partly
  out of view,
* an ancestor lowers its opacity, as `Opacity` and `FadeTransition` do,
* an ancestor scales or rotates it, as `Transform`, `FittedBox` and
  `ScaleTransition` can: the system ignores taps on a button that is not drawn
  at its own size,
* an ancestor applies an image filter to it, as `ImageFiltered` does, and as
  `Transform`, `ScaleTransition` and `AnimatedScale` do with a `filterQuality`,
* it lies under the status bar, the navigation bar or the keyboard,
* content that keeps pointer events from reaching it covers it, such as a
  dialog, an open drawer, a bottom sheet, a menu or a snack bar.

Once hidden, the button reappears after it has stayed fully visible for a
moment, so that standard dialogs, menus and sheets can finish their closing
transitions; a route with a longer closing transition can still be visible
when the button reappears. Covering content is found by hit testing points
across the button, so content that lets pointer events through, such as a
tooltip, or that is narrower than 48 logical pixels can go unnoticed; keep such
content away from the button. While a scroll view scrolls, covering content
cannot be checked: content that covered the button when scrolling started still
hides it, content that moves over a shown button goes unnoticed, and a button
that scrolls into view appears once scrolling has ended.
Shader masks and color filters, such as those of a list that fades at its
edges, neither apply to the system button nor hide it. The system also ignores
taps for a moment after the button appears.

When the font size or the display size changes while the app runs, the widget
replaces the system button, which is missing for a moment. A change of the
display size also ends a request in progress without a result.

When the user closes the system confirmation without answering, the controller
reports `OneTapLocationDiagnostic.tapWithoutAuthorization`. The plugin tells
the confirmation apart from other screens that pause the app, such as a
permission dialog of another plugin, by the activity that the system opens;
where that activity cannot be identified, such screens report the diagnostic
as well. The diagnostic is not reported while several buttons are shown,
because the tapped one is unknown.

The fallback button on Android 7–16 is an ordinary widget, so none of these
rules apply to it.

## iOS

The first tap shows a system confirmation that explains the sharing. Once the
user allows access, later taps report a position right away, and the
confirmation does not come back when the app is started again.

When the user leaves the app while the confirmation is open, by locking the
phone or by switching to another app, the confirmation closes unanswered and
the controller reports `OneTapLocationDiagnostic.tapWithoutAuthorization`.
Taps that follow in the same run of the app report the diagnostic as well,
without showing the confirmation again, so the button appears to do nothing.
Starting the app again shows the confirmation.

When the user turns off Precise Location for the app in the system settings,
the system button reports an approximate position: `position.isPrecise` is
false and `position.altitude` is null. The setting decides this whether access
was granted before or after it changed.

A tap reports the position that the system determined for it, which can be one
the system already had, so two taps a moment apart can report the same
position with the same `position.timestamp`.

## Android 7–16

Where the system location button is not available, on Android 7 through 16
and on devices that lack it, the widget shows a fallback button with the same
size and the same results. By default, the fallback button resembles the
system button: a rounded button with the location icon and the English text of
`androidLabel`. It uses `backgroundColor`, `foregroundColor`, `cornerRadius`
and the Android properties of the style; colors that are null come from
`secondaryContainer` and `onSecondaryContainer` of the app's color scheme. As
on the system button, an outline is drawn only when both `androidStrokeColor`
and `androidStrokeWidth` are set.

The system translates the text of its own button, but the fallback button
shows its text as given. Apps that support other languages provide the text:

```dart
OneTapLocationButton(
  style: OneTapLocationButtonStyle(
    androidFallbackLabel: AppLocalizations.of(context)!.preciseLocation,
  ),
  onResult: _handleResult,
)
```

To show a button of your own instead, use `fallbackBuilder`. The widget it
returns is given the size of the system button, and `onPressed` is null while
a request is in progress:

```dart
OneTapLocationButton(
  fallbackBuilder: (BuildContext context, VoidCallback? onPressed) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.my_location),
      label: const Text('Use my location'),
    );
  },
  onResult: _handleResult,
)
```

A tap on the fallback button shows the permission dialog of the system, unless
the app already has precise access, or has approximate access while precise
location is restricted to the system button (see [Availability](#availability)):

* Access granted in the dialog lasts as long as the user chooses there, for
  example while the app is in use. On Android 11 and later, the user can also
  choose "Only this time": Android revokes that access some time after the app
  leaves the foreground and ends the app's process, and the next tap shows the
  dialog again.
* When the user allows only approximate location, the result is
  `OneTapLocationGranted` with `position.isPrecise` set to false. Android
  determines approximate positions at most every ten minutes, so the position
  can be that old; `position.timestamp` tells when it was determined. When
  Android has no approximate position from the last ten minutes, it determines
  a new one: `isLocating` stays true until it arrives, for up to 30 seconds,
  and the result is `OneTapLocationFailed` with
  `OneTapLocationErrorCode.locationUnavailable` if none arrives in that time.
  The next tap offers to change to precise location, unless precise location
  is restricted to the system button (see [Availability](#availability)). When
  the user keeps approximate location there, Android can offer the change once
  more on the next tap; after that, taps report approximate positions without
  asking.
* When the user denies access, the result is `OneTapLocationDenied`. On
  Android 11 and later, once the user has denied access twice, the system
  denies later taps without showing the dialog; on Android 7 to 10, it does so
  once the user chooses not to be asked again.
* On Android 11 and later, when the app has no location access, Android
  reports a dialog that the user closes without answering, for example with
  Back, as a denial, so the result is `OneTapLocationDenied` as well; this does
  not count as one of the two denials. When the app already has approximate
  access, closing the dialog keeps that access, and the tap continues as
  described for approximate location. On Android 7 to 10, Back does not close
  the dialog.
* When the request is interrupted before the user answers, for example
  because another permission request is in progress, the controller reports
  `OneTapLocationDiagnostic.tapWithoutAuthorization`.

## Other location packages

The widget reports one position per tap, so an app that also tracks the
location, or needs it without a tap, keeps the package it already has. This
plugin declares no runtime location permission of its own, and neither
`geolocator` nor `permission_handler` declares one, so the app's own
`ACCESS_FINE_LOCATION` declaration is the only one in the merged manifest.
The entries this plugin does add are listed in
[Android setup](#android-setup).

What the packages share is the `onlyForLocationButton` flag described in
[Google Play location policy](#google-play-location-policy):

* With the flag, no other package can request precise location. The flag
  restricts precise location to the system button, so the runtime request that
  `geolocator` and `permission_handler` issue offers approximate location
  only, whatever the target API level of the app: `ACCESS_FINE_LOCATION` is
  denied and `ACCESS_COARSE_LOCATION` granted. An app that needs precise
  location for another feature declares `ACCESS_FINE_LOCATION` without the
  flag, which the policy allows only for a core, ongoing feature that neither
  the location button nor approximate location can serve.
* While access granted through the system button lasts, every package sees
  it. Android grants the permission to the app, not to the caller, so once a
  tap has granted precise access, `Permission.location.status` reports it as
  granted and `Geolocator.checkPermission()` answers `whileInUse`, or
  `always` where the app declares and holds background access. That
  access is one-time: the system revokes it about a minute after the app
  leaves the foreground and ends the app's process, so a status the app stored
  earlier does not describe the next launch.

Checked with geolocator 14.1.1 and permission_handler 13.0.2.

## Testing

Tests that run on the host, such as widget tests, do not run the platform code
of the plugin, so there the widget shows nothing that can be tapped, and
`checkAvailability()` cannot determine the availability on iOS and Android.
Install the fake from `package:one_tap_location/testing.dart` before pumping the
widgets:

```dart
late FakeOneTapLocation location;

setUp(() {
  location = FakeOneTapLocation.install();
  addTearDown(location.uninstall);
});

testWidgets('shows the coordinates after a tap', (WidgetTester tester) async {
  location.result = OneTapLocationGranted(
    OneTapPosition(
      latitude: 41.0082,
      longitude: 28.9784,
      timestamp: DateTime.utc(2026, 9, 16),
      isPrecise: true,
    ),
  );
  await tester.pumpWidget(const MaterialApp(home: AddressForm()));

  await tester.tap(find.byType(OneTapLocationButton));
  await tester.pump();

  expect(find.text('41.0082, 28.9784'), findsOneWidget);
});
```

The fake follows the target platform of the test. On Android it shows the
fallback button, or a stand-in for the system button when
`hasAndroidSystemButton` is true; on iOS it shows a stand-in for
`CLLocationButton` with the size `iosButtonSize`, or nothing when
`hasIOSSystemButton` is false, as in iPhone and iPad apps on Apple Vision Pro
with visionOS 26.1 or later. The size does not follow the style: it defaults to
the size of the system button with the default style, so set it when the app
uses another label, icon or font size. Stand-ins resemble the fallback button,
so golden files show the layout of the app, not the look of the system buttons.

With a `result`, a tap reports it once the tap has been handled. Without one,
each tap adds a request to `location.requests`, oldest first, and the request
stays pending until the test answers it with `complete` or `dismiss`. Calling
`grantAccess` before `complete` lets the test check the app while the position
is determined. The button receives each of these calls right away; pump a frame
to see its effect.

## Android setup

The plugin requires Android 7 (API level 24) or later. An app whose `minSdk`
is `flutter.minSdkVersion` gets 24 from Flutter 3.44; a lower `minSdk` fails
the build when the manifests are merged.

The system location button is available on Android 17 (API level 37) and
later. The plugin compiles against API level 36, so an app can keep
`compileSdk` 36 unless it declares the `onlyForLocationButton` flag described
in [Google Play location policy](#google-play-location-policy).

Declare the location permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

The plugin adds two entries to the manifest of every app that depends on it,
including apps that show the widget only on iOS:

* `android.permission.USE_LOCATION_BUTTON`, which the system button requires.
  Android grants this normal permission at install time without asking the
  user. None of the Google Play pages listed in
  [Google Play location policy](#google-play-location-policy) names it.
* A `<queries>` entry for the action
  `android.app.permissionui.action.REQUEST_LOCATION_BUTTON_PERMISSIONS`, which
  lets the plugin recognize the system confirmation of the location button.

Removing these entries with `tools:node="remove"` is not supported.

Without `ACCESS_FINE_LOCATION`, the system button is not shown. The fallback
button needs both permissions: when either one is not declared, a tap reports a
`PlatformException` with the code `missingPermission` to
`FlutterError.onError`, and `onResult` is not called.

Access granted through the system button is one-time. About a minute after the
app leaves the foreground, the system revokes it and ends the app's process, so
save any state the app needs to restore. After the app is updated, the first
tap can show the confirmation again even if the user allowed access before.
Once the user has denied access twice, the system denies later taps without
showing its confirmation, and the user has to allow location access for the app
in the system settings.

## Google Play location policy

Google Play has announced location rules that take effect on January 27, 2027.
This section summarizes the pages listed below as they read on September 16,
2026. The pages, not this summary, define the policy, and the date has moved
before: in early August 2026, the preview gave October 28, 2026.

For apps that target Android 17 (API level 37) or later:

* An app that needs precise location only for one-time actions that the user
  starts, such as searching nearby, sharing the location once, tagging content
  with a location or filling in an address, must use the system location
  button and declare `ACCESS_FINE_LOCATION` with the `onlyForLocationButton`
  flag. Updates of apps that do not comply may be rejected.
* `ACCESS_FINE_LOCATION` without the flag is allowed only for a core, ongoing
  feature, such as turn-by-turn navigation, that neither the location button
  nor approximate location can serve.

The button rules apply once an app targets API level 37. Google Play has not
announced when it will require that target level. Apps created from the Flutter
template take `targetSdk` from the Flutter version that builds them, so
upgrading Flutter can raise it.

Two rules apply at any target API level. The policy allows
`ACCESS_FINE_LOCATION` only for features that approximate location cannot
serve; features that work with approximate location use
`ACCESS_COARSE_LOCATION` only. The help article also requires a Play Console
declaration, available from November 2026, from apps that request
`ACCESS_FINE_LOCATION`. The policy adds that apps requesting location
permissions, including the location button, go through a declaration process
and review. Neither page says whether an app that declares
`ACCESS_FINE_LOCATION` only with the flag has to complete the declaration.

An app in the first case declares in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission
    android:name="android.permission.ACCESS_FINE_LOCATION"
    android:usesPermissionFlags="onlyForLocationButton" />
```

It also sets `compileSdk` to 37 or later: the Android 16 SDK platforms do not
define the flag, and the build fails with an AAPT error. The Android Gradle
plugin supports API level 37 from version 9.1.1; the version 9.0.1 of the
Flutter 3.44 template builds but prints a warning. The help article shows
`android:onlyForLocationButton="true"` instead, but Android defines no attribute
of that name; the flag is a value of `android:usesPermissionFlags`.

With the flag, the system location button still grants precise location,
while the permission dialog offers approximate location only, whatever the
target API level of the app; Android 16 and earlier ignore the flag. On a
device with Android 17 or later whose system does not provide the location
button, the fallback button can therefore obtain approximate location at most;
`isPreciseLocationRestrictedToSystemButton` tells the app when the flag
applies.

Sources:

* [Minimum Scope: Foreground Location Access and the Location Button](https://support.google.com/googleplay/android-developer/answer/17033915)
* [Preview: Permissions and APIs that Access Sensitive Information](https://support.google.com/googleplay/android-developer/answer/16909972), and its [copy of August 2, 2026](https://web.archive.org/web/20260802124115/https://support.google.com/googleplay/android-developer/answer/16909972?hl=en)
* [Target API level requirements for Google Play apps](https://support.google.com/googleplay/android-developer/answer/11926878)
* [Request session-based location access with the location button](https://developer.android.com/guide/topics/permissions/private-alternatives/location-button)
* [`usesPermissionFlags`](https://developer.android.com/reference/android/R.attr#usesPermissionFlags)

## iOS setup

The plugin requires iOS 15 or later. Set the iOS deployment target of the
`Runner` target to 15.0 and, when using CocoaPods, the platform in
`ios/Podfile`:

```ruby
platform :ios, '15.0'
```

Xcode 27 builds for iOS 15 and later, while the Flutter pod still targets
iOS 13, so `pod install` leaves a target that Xcode rejects with "The iOS
deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 13.0". Until the
Flutter pod moves, raise every pod target in the `post_install` hook that
`flutter create` writes into `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

Add a location usage description to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is used to fill in your address.</string>
```

## License

BSD 3-Clause. See [LICENSE](LICENSE).
