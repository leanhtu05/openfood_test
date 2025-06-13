# Script để sửa lỗi authentication
Write-Host "========================================" -ForegroundColor Green
Write-Host "    SỬA LỖI AUTHENTICATION FLUTTER" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 1. Clean project
Write-Host "1. Cleaning project..." -ForegroundColor Yellow
flutter clean
if (Test-Path "android") {
    Set-Location android
    ./gradlew clean
    Set-Location ..
}

# 2. Get dependencies
Write-Host "2. Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# 3. Lấy SHA-1 fingerprint
Write-Host "3. Lấy SHA-1 fingerprint..." -ForegroundColor Yellow
Write-Host ""
Set-Location android
Write-Host "Debug SHA-1 fingerprint:" -ForegroundColor Cyan
./gradlew signingReport | Select-String "SHA1"
Set-Location ..

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "    HƯỚNG DẪN CẤU HINH FIREBASE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "BƯỚC 1: Cập nhật SHA-1 trong Firebase Console" -ForegroundColor Yellow
Write-Host "1. Vào: https://console.firebase.google.com" -ForegroundColor White
Write-Host "2. Chọn project: food-ai-96ef6" -ForegroundColor White
Write-Host "3. Vào Project Settings > General" -ForegroundColor White
Write-Host "4. Chọn app Android: com.example.openfood_test" -ForegroundColor White
Write-Host "5. Thêm SHA-1 fingerprint từ output trên" -ForegroundColor White
Write-Host "6. Tải lại file google-services.json mới" -ForegroundColor White
Write-Host "7. Thay thế file android/app/google-services.json" -ForegroundColor White
Write-Host ""

Write-Host "BƯỚC 2: Cấu hình Google Sign-In" -ForegroundColor Yellow
Write-Host "1. Vào: https://console.cloud.google.com" -ForegroundColor White
Write-Host "2. Chọn project: food-ai-96ef6" -ForegroundColor White
Write-Host "3. Vào APIs & Services > Credentials" -ForegroundColor White
Write-Host "4. Tạo OAuth 2.0 Client ID cho Android:" -ForegroundColor White
Write-Host "   - Application type: Android" -ForegroundColor White
Write-Host "   - Package name: com.example.openfood_test" -ForegroundColor White
Write-Host "   - SHA-1: (copy từ output trên)" -ForegroundColor White
Write-Host ""

Write-Host "BƯỚC 3: Bật Authentication Methods" -ForegroundColor Yellow
Write-Host "1. Vào Firebase Console > Authentication > Sign-in method" -ForegroundColor White
Write-Host "2. Bật các phương thức:" -ForegroundColor White
Write-Host "   - Email/Password" -ForegroundColor White
Write-Host "   - Phone" -ForegroundColor White
Write-Host "   - Google" -ForegroundColor White
Write-Host ""

Write-Host "BƯỚC 4: Test lại ứng dụng" -ForegroundColor Yellow
Write-Host "flutter run --debug" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Hoàn thành! Hãy làm theo các bước trên." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
