# ESignFilenameFix (experimental)

Standalone **arm64 iOS dylib** for **ESign** with class `YYYDownloadItem`.

For links such as `bawa_1.4.6-new`, it checks the *completed file contents*, recognizes IPA archives with `Payload/<app>.app/` entries, and adds `.ipa` to both file path and download display name.

- Hooks completed download state via `YYYDownloadItem -save` and `-isDownloaded`, not the download button.
- Checks ZIP central-directory filenames in a background queue, without decompression.
- Preserves existing extensions, refuses to overwrite any file, and leaves non-IPA archives unchanged.
- Re-sign the injected dylib with your own iOS signing process.

**Experimental:** No on-device test has yet been performed. Runtime compatibility depends on the exact ESign version. Maintain a backup and test on a nonessential install first.
