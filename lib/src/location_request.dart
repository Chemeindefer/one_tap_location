// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';

import 'codec.dart';
import 'diagnostic.dart';
import 'platform.dart';
import 'result.dart';

/// Receives the progress of a [LocationRequest].
///
/// [onDone] is called last. No member is called after [LocationRequest.cancel].
abstract interface class LocationRequestListener {
  /// Access was granted, and the position is being determined.
  void onLocating();

  /// The request has an outcome.
  void onResult(OneTapLocationResult result);

  /// The request reports a diagnostic instead of an outcome.
  void onDiagnostic(OneTapLocationDiagnostic diagnostic);

  /// The request has ended.
  void onDone();
}

/// A request for location access and a position, started by a tap on a button
/// that the plugin draws.
abstract interface class LocationRequest {
  /// Starts the request.
  ///
  /// [listener] is not called before this method returns.
  void start(LocationRequestListener listener);

  /// Ends the request without informing its listener.
  void cancel();
}

/// Identifies the position requests of fallback buttons on the platform side.
int _nextPositionRequestId = 0;

/// Asks for location access with the permission dialog of the system, and then
/// for a position.
final class FallbackLocationRequest implements LocationRequest {
  bool _isCancelled = false;
  int? _positionRequestId;

  @override
  void start(LocationRequestListener listener) {
    unawaited(_run(listener));
  }

  @override
  void cancel() {
    _isCancelled = true;
    final int? positionRequestId = _positionRequestId;
    if (positionRequestId != null) {
      unawaited(
        pluginChannel
            .invokeMethod<void>('cancelFallbackPosition', positionRequestId)
            .catchError(
              (Object error) {},
              test: (Object error) => error is MissingPluginException,
            ),
      );
    }
  }

  Future<void> _run(LocationRequestListener listener) async {
    try {
      final FallbackPermissionAnswer answer = decodePermissionAnswer(
        await pluginChannel.invokeMethod<String>('requestFallbackPermission'),
      );
      if (_isCancelled) {
        return;
      }
      switch (answer) {
        case FallbackPermissionAnswer.granted:
          await _locate(listener);
        case FallbackPermissionAnswer.denied:
          listener.onResult(const OneTapLocationDenied());
        case FallbackPermissionAnswer.cancelled:
          listener.onDiagnostic(
            OneTapLocationDiagnostic.tapWithoutAuthorization,
          );
      }
    } catch (exception, stack) {
      reportError(
        exception,
        stack,
        'while obtaining the location with the fallback button',
      );
    } finally {
      if (!_isCancelled) {
        listener.onDone();
      }
    }
  }

  Future<void> _locate(LocationRequestListener listener) async {
    final int requestId = _nextPositionRequestId++;
    _positionRequestId = requestId;
    listener.onLocating();
    final Map<Object?, Object?>? result;
    try {
      result = await pluginChannel.invokeMapMethod<Object?, Object?>(
        'requestFallbackPosition',
        requestId,
      );
    } finally {
      _positionRequestId = null;
    }
    // The platform answers a cancelled request without a result.
    if (!_isCancelled && result != null) {
      listener.onResult(decodeResult(result));
    }
  }
}
