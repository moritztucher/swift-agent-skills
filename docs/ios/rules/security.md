# Security Rules

- **No hardcoded secrets** — never commit API keys, tokens, or passwords in source code
- **HTTPS only** — all network requests must use HTTPS, no exceptions
- **Keychain** for tokens, passwords, and credentials — never UserDefaults for sensitive data
- **PrivacyInfo.xcprivacy** — include and keep updated for App Store compliance
- **Input validation** at system boundaries — user input, API responses, deep links
- **SSL/TLS** — never disable certificate validation, even in debug builds
- **Biometrics** — use `LocalAuthentication` framework for biometric auth, always provide a fallback
