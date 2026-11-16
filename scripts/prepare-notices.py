#!/usr/bin/env python3
"""Collect upstream notices into a media-free package folder. Python 3.9."""
import argparse
from pathlib import Path
import shutil
import re
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build-dir',type=Path,required=True)
    p.add_argument('--platform',choices=['macos','simulator','device'],required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    files={
        'ETLegacy-GPL.txt':ROOT/'COPYING.txt',
        'Theora-COPYING.txt':ROOT/'libs/theora/COPYING',
        'Theora-LICENSE.txt':ROOT/'libs/theora/LICENSE',
        'Ogg-COPYING.txt':ROOT/'libs/ogg/COPYING',
        'Vorbis-COPYING.txt':ROOT/'libs/vorbis/COPYING',
        'PNG-LICENSE.txt':ROOT/'libs/libpng/LICENSE',
        'JPEG-LICENSE.md':ROOT/'libs/jpegturbo/LICENSE.md',
        'JPEG-IJG.txt':ROOT/'libs/jpegturbo/README.ijg',
        'cJSON-LICENSE.txt':ROOT/'libs/cjson/LICENSE',
        'Zlib-README.txt':ROOT/'libs/zlib/README',
        'MiniZip-info.txt':ROOT/'libs/minizip/MiniZip64_info.txt',
        'FindLocale-LICENSE.txt':ROOT/'libs/findlocale/LICENSE',
        'SDL-LICENSE.txt':args.build_dir/'libs/sdl2/src/bundled_sdl/LICENSE.txt',
        'FreeType-FTL.txt':args.build_dir/'libs/freetype/src/bundled_freetype/docs/FTL.TXT',
    }
    if args.platform!='macos':
        files.update({'GL4ES-LICENSE.txt':ROOT/'build/sources/gl4es/LICENSE','ANGLE-LICENSE.txt':ROOT/'build/dependencies/angle-prebuilt/LICENSE.ANGLE'})
    for name,source in files.items():
        if not source.is_file():raise RuntimeError('Missing dependency notice: '+str(source))
        shutil.copy2(source,args.output/name)
    # Mac-only optional backends: retain every available upstream notice.
    for relative in ['libs/curl/COPYING','libs/wolfssl/COPYING','libs/openal/COPYING','libs/openssl/LICENSE','libs/openssl/LICENSE.txt','libs/glew/LICENSE.txt']:
        source=ROOT/relative
        if source.is_file():shutil.copy2(source,args.output/(source.parent.name+'-'+source.name))
    sqlite=(ROOT/'libs/sqlite3/src/sqlite3.c').read_text(errors='replace')
    # Keep the actual public-domain dedication, not the amalgamation preface.
    dedication=next(block for block in re.findall(r'/\*.*?\*/',sqlite[:16384],re.S) if 'author disclaims copyright' in block)
    (args.output/'SQLite-notice.txt').write_text(dedication+'\n')
    minizip=(ROOT/'libs/minizip/unzip.h').read_text()
    (args.output/'MiniZip-LICENSE.txt').write_text(minizip[:minizip.index('*/')+2]+'\n')
    (args.output/'ACKNOWLEDGEMENTS.txt').write_text('ETPad uses ET: Legacy and the Wolfenstein: Enemy Territory GPL source.\nThis software is based in part on the work of the FreeType Team and the Independent JPEG Group.\nSDL, GL4ES, ANGLE, Ogg/Vorbis/Theora, libpng, zlib/MiniZip, cJSON, SQLite and FindLocale retain their upstream notices in this folder.\nOriginal Enemy Territory game media is not included.\n')
if __name__=='__main__':main()
