# LCSign CertLoader (experimental)

An optional iOS arm64 dynamic library intended for LCSign v16. It tries to replace reads of `cert.dat` with a ZIP built from certificate assets placed in the app bundle under `signing-assets/iKiraPlus`:

- `cert.p12`
- `cert.mobileprovision`
- `cert.txt` or `pwd.txt` (password)

The dylib never contains actual certificate files or secrets. It does **not** modify AutoSource.

## Build

Use the **Build LCSign CertLoader Dylib** workflow in GitHub Actions. The output artifact is `LCSignCertLoader-ios-arm64`.

## Limitations

This is an experimental Foundation file-read interception. It may not detect lower-level file access or previously imported certificates already saved in app data. The final app needs complete signing and testing on a device. Keep the known-good AutoSource build. Never commit a P12 or mobileprovision to this public repository.
