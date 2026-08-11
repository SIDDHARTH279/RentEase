# RentEase — Store release checklist

## Android (Play Store)

1. Create Play Console app (`com.example.rentease_app` → change to your real package before release)
2. Generate release keystore; configure `android/app/build.gradle.kts` signing
3. Add release SHA-1/SHA-256 to Firebase + Google Cloud OAuth Android client
4. Build: `flutter build appbundle --release`
5. Upload AAB; complete store listing (title, screenshots, privacy policy URL)
6. Privacy policy must cover: email, phone, FCM tokens, payment data (Razorpay), uploaded documents

## iOS (App Store)

1. Apple Developer account + App ID
2. Configure Firebase iOS app + `GoogleService-Info.plist`
3. Enable Sign in with Google URL schemes
4. `flutter build ipa --release`
5. App Store Connect: screenshots, privacy nutrition labels, review notes

## Beta

- Internal testing track (Play) / TestFlight (iOS)
- Verify: invite deep link, Google tenant join, Razorpay test payments, chat, documents upload

## Legal

- Host privacy policy + terms (link from store listing)
- Razorpay / Google OAuth compliance disclosures
