#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
/usr/bin/python3 - "$project_root" <<'PY'
import hashlib
import io
import pathlib
import sys
import tarfile
import urllib.request
import zipfile

root = pathlib.Path(sys.argv[1])
resources = root / 'Sources/RedAlertMac/Resources'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def fetch(url, expected):
    request = urllib.request.Request(url, headers={'User-Agent': 'RedAlertMac-build/0.1'})
    with urllib.request.urlopen(request, timeout=120) as response:
        data = response.read()
    if digest(data) != expected:
        raise RuntimeError('Build dependency SHA-256 mismatch: ' + url)
    return data

def valid(path, sha):
    return path.is_file() and digest(path.read_bytes()) == sha

dll = resources / 'Compatibility/ddraw.dll'
if not valid(dll, '85e0f7d530dfda134793a57cb3e76b0287dcc96892ee57162dd68f47283b03a9'):
    print('Downloading verified cnc-ddraw 7.1.0.0…', flush=True)
    archive = fetch('https://github.com/FunkyFr3sh/cnc-ddraw/releases/download/v7.1.0.0/cnc-ddraw.zip',
                    '0b13ab89a64c9918189b1dadd449ef6ed3cb3b7b19cabd96d8adbd95505bb908')
    with zipfile.ZipFile(io.BytesIO(archive)) as package:
        dll.parent.mkdir(parents=True, exist_ok=True)
        dll.write_bytes(package.read('ddraw.dll'))

tool = resources / 'Tools/7zz'
if not valid(tool, '8e495531e1b2b8cb169ca583493922d4ab386007756418c15b95f07f642c35fb'):
    print('Downloading verified 7-Zip 26.05 for macOS…', flush=True)
    archive = fetch('https://github.com/ip7z/7zip/releases/download/26.05/7z2605-mac.tar.xz',
                    '12ef6830317743cfd3f0ab1724bde43fcc270d8b6d8564f8c12c2a2b7f993570')
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:xz') as package:
        member = next(m for m in package.getmembers() if m.name.lstrip('./') == '7zz')
        tool.parent.mkdir(parents=True, exist_ok=True)
        tool.write_bytes(package.extractfile(member).read())
    tool.chmod(0o755)

source = resources / 'Tools/7z2605-src.tar.xz'
if not valid(source, '0b6080b8c3e7a579161d2d495224c0e51c467576cb4c7048b0ab485ef44cc22e'):
    print('Downloading corresponding 7-Zip 26.05 source for redistribution…', flush=True)
    archive = fetch('https://github.com/ip7z/7zip/releases/download/26.05/7z2605-src.tar.xz',
                    '0b6080b8c3e7a579161d2d495224c0e51c467576cb4c7048b0ab485ef44cc22e')
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_bytes(archive)

print('Build resources verified. No game data is downloaded for compilation.')
PY
