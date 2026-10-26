# Cyber Uday

Cyber Uday is an AI-powered cybersecurity platform that helps people identify phishing, scams, malicious links, online fraud, fake websites, and other digital threats.

## Development

```bash
flutter pub get
flutter run
```

## Web build

```bash
flutter build web
```

The web build is configured for [cyberuday.in](https://cyberuday.in) with Cyber Uday PWA, SEO, and social-sharing metadata.

## Cyber Cell Portal

Cyber Cell login uses the existing Firebase Authentication email/password account,
then authorizes the Firebase UID against `users/{uid}` in Firestore. The document
must contain `cyber_cell_officer`, `cyber_cell_admin`, or `admin` in `role` (or
`roles`). An explicit `isActive: false` disables access.

For the authorized test account `riapagar21@gmail.com`, create or verify the
Firebase Authentication user in Firebase Console and set its Firestore document
at `users/{uid}` to:

```json
{
	"email": "riapagar21@gmail.com",
	"role": "cyber_cell_officer",
	"isActive": true
}
```

Do not store the password in Firestore or source code. Deploy the protected
Functions and rules before testing:

```bash
firebase deploy --only functions:createCyberCellCase,functions:cyberCellApi,firestore:rules
flutter run -d chrome
```
