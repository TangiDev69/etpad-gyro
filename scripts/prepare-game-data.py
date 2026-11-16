#!/usr/bin/env python3
"""Fetch official original data locally, or validate/import owned pak files. Python 3.9."""
import argparse
import hashlib
import io
from pathlib import Path
import re
import shutil
import tarfile
import tempfile
import urllib.request
import zipfile

URL = 'https://cdn.splashdamage.com/downloads/games/wet/et260b.x86_full.zip'
ARCHIVE_HASH = '2a8fef8e8558efffcad658bb9a8b12df8740418b3514142350eba3b7641eb3e0'
PAKS = {
    'pak0.pk3': '712966b20e06523fe81419516500e499c86b2b4fec823856ddbd333fcb3d26e5',
    'pak1.pk3': '5610fd749024405b4425a7ce6397e58187b941d22092ef11d4844b427df53e5d',
    'pak2.pk3': 'a48ab749a1a12ab4d9137286b1f23d642c29da59845b2bafc8f64e052cf06f3e',
}

def verify(path, expected):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    if h.hexdigest() != expected:
        raise ValueError('SHA-256 mismatch: ' + path.name)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--import-from', type=Path, help='Folder containing the three owned original paks')
    parser.add_argument('--download', action='store_true', help='Download original EULA game data for local use')
    args = parser.parse_args()
    if bool(args.import_from) == args.download:
        parser.error('Choose --download or --import-from FOLDER')
    root = Path(__file__).resolve().parent.parent
    destination = root / 'game-data' / 'etmain'
    destination.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='etpad-data-', dir=str(destination.parent)) as temp:
        staging = Path(temp)
        if args.download:
            downloads = root / 'downloads'
            downloads.mkdir(exist_ok=True)
            archive = downloads / 'et260b.x86_full.zip'
            if not archive.exists():
                partial = archive.with_suffix('.partial')
                urllib.request.urlretrieve(URL, str(partial))
                verify(partial, ARCHIVE_HASH)
                partial.replace(archive)
            verify(archive, ARCHIVE_HASH)
            with zipfile.ZipFile(archive) as outer:
                run = outer.read('et260b.x86_keygen_V03.run')
            # Makeself's filesizes gives the appended gzip tar length. Never execute installer code.
            match = re.search(br'\nfilesizes="([0-9]+)"', run[:16384])
            if not match:
                raise ValueError('Unrecognized official archive layout')
            size = int(match.group(1))
            with tarfile.open(fileobj=io.BytesIO(run[-size:]), mode='r:gz') as tar:
                for member in tar.getmembers():
                    name = member.name.removeprefix('./')
                    if name in ['etmain/' + p for p in PAKS]:
                        if not member.isfile():
                            raise ValueError('Pak is not a regular file')
                        with tar.extractfile(member) as src, (staging / Path(name).name).open('wb') as dst:
                            shutil.copyfileobj(src, dst)
        else:
            for name in PAKS:
                shutil.copyfile(args.import_from / name, staging / name)
        for name, expected in PAKS.items():
            verify(staging / name, expected)
        destination.mkdir(exist_ok=True)
        for name in PAKS:
            (staging / name).replace(destination / name)
    print('Verified original game data: ' + str(destination))

if __name__ == '__main__':
    main()
