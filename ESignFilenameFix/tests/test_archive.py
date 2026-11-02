import ctypes
import pathlib
import subprocess
import tempfile
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as d:
    dylib = pathlib.Path(d) / 'libtest.so'
    subprocess.run(['clang', '-shared', '-fPIC', '-o', str(dylib),
                    str(root/'src'/'IPAArchiveCheck.c')], check=True)
    test = ctypes.CDLL(str(dylib)).esign_is_ipa_archive
    test.argtypes = [ctypes.c_char_p]
    test.restype = ctypes.c_int
    def make(name, members):
        p = pathlib.Path(d)/name
        with zipfile.ZipFile(p,'w') as z:
            for m in members: z.writestr(m, b'placeholder')
        return str(p).encode()
    assert test(make('real_ipa_without_extension', ['Payload/Example.app/Info.plist'])) == 1
    assert test(make('zip_without_app', ['document.txt'])) == 0
    assert test(make('zip_with_nested_app', ['Other/App.app/Info.plist'])) == 0
    assert test(make('zip_with_app', ['Payload/Example.app/Info.plist', 'Payload/Example.app/file'])) == 1
    assert test(b'/file/that/does/not/exist') == 0
print('IPA archive detection: 5 tests passed')
