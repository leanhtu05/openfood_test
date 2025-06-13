@echo off
echo ========================================
echo    LAY SHA-1 FINGERPRINT CHO FIREBASE
echo ========================================
echo.

echo Dang lay SHA-1 fingerprint cho debug keystore...
echo.

cd /d "%~dp0android"

echo Debug SHA-1:
gradlew signingReport

echo.
echo ========================================
echo HUONG DAN CAU HINH FIREBASE:
echo ========================================
echo.
echo 1. Copy SHA-1 fingerprint tu output tren
echo 2. Vao Firebase Console: https://console.firebase.google.com
echo 3. Chon project: food-ai-96ef6
echo 4. Vao Project Settings ^> General
echo 5. Chon app Android: com.example.openfood_test
echo 6. Them SHA-1 fingerprint vao muc "SHA certificate fingerprints"
echo 7. Tai lai file google-services.json moi
echo 8. Thay the file android/app/google-services.json
echo.
echo ========================================
echo CAU HINH GOOGLE SIGN-IN:
echo ========================================
echo.
echo 1. Vao Google Cloud Console: https://console.cloud.google.com
echo 2. Chon project: food-ai-96ef6
echo 3. Vao APIs ^& Services ^> Credentials
echo 4. Tao OAuth 2.0 Client ID cho Android
echo 5. Nhap package name: com.example.openfood_test
echo 6. Nhap SHA-1 fingerprint vua lay duoc
echo 7. Luu lai Client ID
echo.
pause
