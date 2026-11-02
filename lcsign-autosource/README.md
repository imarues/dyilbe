# LCSign AutoSource Dylib — experimental

A **real iOS arm64 dynamic library** built with Apple's own iOS SDK in a public
GitHub Actions macOS runner. Designed for **LCSign v16**, not standalone apps.

After the app becomes active and its main tab bar is visible, it requests the
existing `loadcontroller://addsource?...` URL once. This is the mechanism that
already worked when the user tapped the v16 one-tap link.

Source URL: `https://ikiraplus.pages.dev/IPA-AR.json`

## Build

GitHub Actions → **Build LCSign AutoSource Dylib** → Run workflow, or push a change
under `lcsign-autosource/`. Download the `LCSignAutoSource-ios-arm64` artifact.

## Important limitations

- **Build only. Not yet injected into v16 IPA.** A dylib in a zip does nothing
  until the app is explicitly configured to load it.
- This library will not run during onboarding. It requires a visible native
  `UITabBar` and no presented modal, which prevents premature injection; if
  LCSign's UI implementation does not create a `UITabBar`, the automatic attempt
  deliberately does **not** run. The manual one-tap option in v16 remains.
- `openURL` success only confirms the URL was opened. It does **not** prove the
  subscription was persisted. Test the repository list on device.
- The output is **ad-hoc signed for build validation only**. Injecting it into
  an IPA requires correctly placing it in the app, adding an appropriate Mach-O
  load command, signing nested dylibs with a valid iOS certificate, then
  signing the enclosing app and testing. Do not install a partially signed IPA.
- This public repository contains **no P12, mobileprovision, password, IPA,
  certificate, UDID, or account secret**.
