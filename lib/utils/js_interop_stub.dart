// This is a stub file to provide fake js_interop functionality on non-web platforms
// It's used to make the firebase_web_fix work on all platforms

// Define a fake toJS extension to avoid errors on mobile/desktop
extension ToJSExtension<T> on T {
  // This doesn't actually do anything on non-web platforms
  // It's just here to prevent compile-time errors
  get toJS => this;
} 