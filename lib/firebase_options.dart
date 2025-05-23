import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Cấu hình Firebase cho Web - Cần điền appId khi tạo web app
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyChQQ4XTIY5lbgIrQJsXcy7Wp_0Y_uQyQw',
    appId: '1:77790054986:web:YOUR_WEB_APP_ID_HERE',
    messagingSenderId: '77790054986',
    projectId: 'food-ai-96ef6',
    authDomain: 'food-ai-96ef6.firebaseapp.com',
    storageBucket: 'food-ai-96ef6.appspot.com',
  );

  // Cấu hình Firebase cho Android
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyChQQ4XTIY5lbgIrQJsXcy7Wp_0Y_uQyQw',
    appId: '1:77790054986:android:399319a808871431f4b4b3',
    messagingSenderId: '77790054986',
    projectId: 'food-ai-96ef6',
    storageBucket: 'food-ai-96ef6.appspot.com',
  );

  // Cấu hình Firebase cho iOS - Cần điền các thông số chính xác sau khi tạo app iOS
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyChQQ4XTIY5lbgIrQJsXcy7Wp_0Y_uQyQw',
    appId: '1:77790054986:ios:YOUR_IOS_APP_ID_HERE',
    messagingSenderId: '77790054986',
    projectId: 'food-ai-96ef6',
    storageBucket: 'food-ai-96ef6.appspot.com',
    iosClientId: 'YOUR_IOS_CLIENT_ID_HERE.apps.googleusercontent.com',
    iosBundleId: 'com.example.openfood_test',
  );
}
