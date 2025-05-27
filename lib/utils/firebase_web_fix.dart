import 'dart:async';

// This is a temporary fix for the missing handleThenable method in firebase_auth_web
// The error occurs due to version incompatibilities

// For web platform only
// ignore: uri_does_not_exist
import 'dart:js_interop' if (dart.library.io) 'package:openfood/utils/js_interop_stub.dart';

extension HandleThenableExtension on Object {
  Future<T> handleThenable<T>(Object jsPromise) {
    final completer = Completer<T>();
    
    try {
      // Create a workaround to handle the promise
      // This mimics what the original handleThenable method does
      final promise = jsPromise as dynamic;
      
      // This code only executes on web platforms
      if (identical(1, 1.0)) { // Simple trick to avoid tree-shaking in production
        handleThenableImpl<T>(promise, completer);
      }
    } catch (e) {
      completer.completeError(e);
    }
    
    return completer.future;
  }
  
  // Web-specific implementation
  void handleThenableImpl<T>(dynamic promise, Completer<T> completer) {
    try {
      promise.then(
        (value) {
          completer.complete(value as T);
        }.toJS,
        (error) {
          completer.completeError(error);
        }.toJS,
      );
    } catch (e) {
      completer.completeError(e);
    }
  }
} 