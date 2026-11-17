#!/usr/bin/env python3
"""Build source-pinned Omni-bot as an app-signable iOS framework (Apple Python 3.9).

Call serially with other ETPad builds. Bundles only script/navigation data from
ET: Legacy's hashed distribution; its downloaded macOS executable is excluded.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
COMMIT = 'b3f10f334de625765100bbfeacc5eac95c098607'
GM_COMMIT = '2d24f6e500c327aa2e99f3572e8e2f4b285e37f4'
URL = 'https://github.com/jswigart/omni-bot.git'
BOOST_SHA = '7009fe1faa1697476bdc7027703a2badb84e849b7b0baad5086b087b971f8617'
DATA_SHA = '7c4a3c1b6f185e48267764b3fc5ffcee6c7b61cec2505d5b6b38847f92502313'


def run(*args, env=None):
    subprocess.run([str(x) for x in args], check=True, cwd=ROOT, env=env)


def download(url, target, expected):
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        partial = target.with_suffix(target.suffix + '.partial')
        urllib.request.urlretrieve(url, partial)
        if hashlib.sha256(partial.read_bytes()).hexdigest() != expected:
            raise RuntimeError('SHA-256 mismatch: ' + url)
        partial.replace(target)
    if hashlib.sha256(target.read_bytes()).hexdigest() != expected:
        raise RuntimeError('SHA-256 mismatch: ' + str(target))


def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_text() != content:
        path.write_text(content)


def source_inputs():
    ref = ROOT / 'build/sources/omni-bot'
    if not ref.exists():
        ref.parent.mkdir(parents=True, exist_ok=True)
        run('git', 'clone', URL, ref)
        run('git', '-C', ref, 'checkout', '--detach', COMMIT)
    revision = subprocess.check_output(['git', '-C', str(ref), 'rev-parse', 'HEAD'], text=True).strip()
    if revision != COMMIT:
        raise RuntimeError('Omni-bot source differs from pinned commit')
    run('git', '-C', ref, 'diff', '--exit-code', 'HEAD')
    sub = '0.83/Omnibot/dependencies/gmscriptex'
    run('git', '-C', ref, 'submodule', 'update', '--init', '--depth', '1', '--', sub)
    gm = ref / sub
    if subprocess.check_output(['git', '-C', str(gm), 'rev-parse', 'HEAD'], text=True).strip() != GM_COMMIT:
        raise RuntimeError('GameMonkey source differs from pinned gitlink')
    run('git', '-C', gm, 'diff', '--exit-code', 'HEAD')
    archive = ROOT / 'build/boost_1_85_0.tar.bz2'
    download('https://archives.boost.io/release/1.85.0/source/boost_1_85_0.tar.bz2', archive, BOOST_SHA)
    boost = ROOT / 'build/sources/boost_1_85_0'
    if not boost.exists():
        with tarfile.open(archive) as bundle:
            for member in bundle.getmembers():
                parts = PurePosixPath(member.name).parts
                if not parts or parts[0] != boost.name or '..' in parts or member.issym() or member.islnk():
                    raise RuntimeError('Unsafe Boost archive member: ' + member.name)
            bundle.extractall(boost.parent)
    return ref / '0.83/Omnibot', boost


def private_source(original, source):
    patched_inputs = {'Common/CMakeLists.txt', 'ET/CMakeLists.txt', 'Common/FileSystem.cpp'}
    def copy_input(src, dst):
        # Patched files are written below only when their final contents change.
        # Avoid restoring upstream contents first and forcing a full rebuild.
        if Path(src).relative_to(original).as_posix() in patched_inputs:
            return str(dst)
        if not Path(dst).exists() or Path(src).read_bytes() != Path(dst).read_bytes():
            shutil.copy2(src, dst)
        return str(dst)
    shutil.copytree(original, source, dirs_exist_ok=True, copy_function=copy_input,
                    ignore=shutil.ignore_patterns('.git'))
    common = (original / 'Common/CMakeLists.txt').read_text()
    old = 'set_target_properties(omnibot-common PROPERTIES COMPILE_FLAGS -pthread -ffriend-injection -fno-strict-aliasing)'
    assert common.count(old) == 1
    common = common.replace(old, 'target_compile_options(omnibot-common PRIVATE -pthread -fno-strict-aliasing)')
    common = common.replace('if(APPLE)\n    find_library(CARBON_FW Carbon)',
                            'if(APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")\n    find_library(CARBON_FW Carbon)')
    write(source / 'Common/CMakeLists.txt', common)
    et = (original / 'ET/CMakeLists.txt').read_text()
    et = et.replace('add_library(omnibot-et MODULE', 'add_library(omnibot-et SHARED')
    et += '''
set_target_properties(omnibot-et PROPERTIES FRAMEWORK TRUE
    OUTPUT_NAME ETPadOmnibot MACOSX_FRAMEWORK_IDENTIFIER org.etlegacy.etpad.omnibot
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO)
'''
    write(source / 'ET/CMakeLists.txt', et)
    filesystem = (original / 'Common/FileSystem.cpp').read_text()
    anchor = 'bool FileSystem::SetWriteDirectory(const fs::path &_dir)\n{\n'
    assert filesystem.count(anchor) == 1
    filesystem = filesystem.replace(anchor, anchor + '''
    // ETPad's script/nav installation lives in a signed read-only framework.
    // Keep user configuration and generated navigation in the app sandbox.
    if (_dir == Utils::GetModFolder())
    {
        try
        {
            fs::path writable = fs::path(g_EngineFuncs->GetLogPath()) / "omni-bot";
            fs::create_directories(writable);
            if (!PHYSFS_setWriteDir(writable.string().c_str()))
                return false;
            PHYSFS_mount(writable.string().c_str(), NULL, 0);
            return true;
        }
        catch (const std::exception &error)
        {
            LOG("ETPad bot write directory: " << error.what());
            return false;
        }
    }
''')
    write(source / 'Common/FileSystem.cpp', filesystem)


def bundle_data(framework):
    archive = ROOT / 'downloads/omnibot-macos-0.93.tar.gz'
    download('https://mirror.etlegacy.com/omnibot/omnibot-macos-0.93.tar.gz', archive, DATA_SHA)
    with tarfile.open(archive) as bundle:
        for member in bundle.getmembers():
            parts = PurePosixPath(member.name).parts
            if len(parts) < 2 or parts[0] != 'omni-bot':
                continue
            relative = parts[1:]
            if relative[0] not in ('et', 'global_scripts', 'README.txt', 'changelog.txt'):
                continue
            if '..' in relative or member.issym() or member.islnk():
                raise RuntimeError('Unsafe bot data member: ' + member.name)
            if not member.isfile():
                continue
            destination = framework.joinpath(*relative)
            data = bundle.extractfile(member).read()
            # The distribution's native library is never copied or executed.
            if destination.suffix.lower() in ('.so', '.dylib', '.dll', '.exe') or data[:4] in (
                    b'\x7fELF', b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf',
                    b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xce') or data[:2] == b'MZ':
                raise RuntimeError('Native executable in bot data: ' + member.name)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)


def build(platform):
    original, boost = source_inputs()
    work = ROOT / 'build/omnibot-ios'
    source = work / 'source'
    private_source(original, source)
    boost_source = work / 'boost-source'
    write(boost_source / 'system.cpp', 'void etpad_boost_system_header_only() {}\n')
    write(boost_source / 'CMakeLists.txt', '''cmake_minimum_required(VERSION 3.20)
project(ETPadBotBoost CXX)
set(CMAKE_CXX_STANDARD 20)
include_directories("${BOOST_ROOT}")
add_compile_definitions(BOOST_ALL_NO_LIB BOOST_FILESYSTEM_STATIC_LINK BOOST_REGEX_STATIC_LINK)
foreach(component filesystem regex)
 file(GLOB sources "${BOOST_ROOT}/libs/${component}/src/*.cpp")
 add_library(boost_${component} STATIC ${sources})
endforeach()
add_library(boost_date_time STATIC "${BOOST_ROOT}/libs/date_time/src/gregorian/greg_month.cpp")
target_compile_definitions(boost_date_time PUBLIC DATE_TIME_INLINE)
add_library(boost_system STATIC system.cpp)
foreach(component filesystem regex date_time system)
 set_target_properties(boost_${component} PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
endforeach()
''')
    sdkname = 'iphonesimulator' if platform == 'simulator' else 'iphoneos'
    sdk = subprocess.check_output(['xcrun', '--sdk', sdkname, '--show-sdk-path'], text=True).strip()
    jobs = min(4, max(1, int(subprocess.check_output(['sysctl', '-n', 'hw.ncpu'])) // 2))
    env = dict(os.environ, SDKROOT=sdk)
    args = ['-G', 'Ninja', '-DCMAKE_SYSTEM_NAME=iOS', '-DCMAKE_OSX_SYSROOT=' + sdk,
            '-DCMAKE_OSX_ARCHITECTURES=arm64', '-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0',
            '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY']
    boost_build = work / platform / 'boost'
    bot_build = work / platform / 'bot'
    run('cmake', '-S', boost_source, '-B', boost_build, *args, '-DBOOST_ROOT=' + str(boost), env=env)
    run('cmake', '--build', boost_build, '--parallel', jobs, env=env)
    libraries = ['-DBoost_' + name.upper() + '_LIBRARY_RELEASE=' + str(boost_build / ('lib/libboost_' + name + '.a'))
                 for name in ('system', 'filesystem', 'regex', 'date_time')]
    run('cmake', '-S', source, '-B', bot_build, *args, '-DOMNIBOT_ET=ON', '-DOMNIBOT_RTCW=OFF',
        '-DOMNIBOT_STATIC_BOOST=ON', '-DBoost_NO_BOOST_CMAKE=ON', '-DBoost_NO_SYSTEM_PATHS=ON',
        '-DBOOST_ROOT=' + str(boost), '-DBoost_INCLUDE_DIR=' + str(boost), *libraries, env=env)
    run('cmake', '--build', bot_build, '--target', 'omnibot-et', '--parallel', jobs, env=env)
    framework = bot_build / 'ET/ETPadOmnibot.framework'
    bundle_data(framework)
    notices = framework / 'Notices'
    notices.mkdir(exist_ok=True)
    shutil.copy2(boost / 'LICENSE_1_0.txt', notices / 'Boost-LICENSE.txt')
    shutil.copy2(original / 'dependencies/physfs/LICENSE.txt', notices / 'PhysFS-LICENSE.txt')
    gm = original / 'dependencies/gmscriptex/gmsrc_ex'
    shutil.copy2(gm / 'doc/GameMonkeyLicense.pdf', notices / 'GameMonkeyLicense.pdf')
    shutil.copy2(gm / 'src/gm/gmMachine.h', notices / 'GameMonkey-copyright.h')
    shutil.copy2(original / 'dependencies/wildmagic/WildMagic3Math.h', notices / 'WildMagic-copyright.h')
    shutil.copy2(original / 'dependencies/physfs/zlib123/zlib.h', notices / 'zlib-copyright.h')
    shutil.copy2(original / 'dependencies/physfs/zlib123/README', notices / 'zlib-README.txt')
    # Preserve notices from the compiled embedded dependencies, not just the
    # umbrella GameMonkey/PhysFS licenses.
    extra_notices = {
        'MathLib-copyright.h': gm / 'src/3rdParty/mathlib/vector.h',
        'LZMA-license.txt': original / 'dependencies/physfs/lzma/lzma.txt',
        'LZMA-LGPL.txt': original / 'dependencies/physfs/lzma/LGPL.txt',
        'FSBAllocator-copyright.h': original / 'Common/FSBAllocator.h',
        'GameMonkeyBindings-copyright.h': original / 'Common/gmBind.h',
        'KeyValueIni-copyright.cpp': original / 'Common/KeyValueIni.cpp',
        'Logger-copyright.h': original / 'Common/Logger.h',
        'Bison-skeleton-notice.txt': gm / 'src/gm/bison.simple',
    }
    for name, path in extra_notices.items():
        shutil.copy2(path, notices / name)
    write(notices / 'OMNIBOT-SOURCE.txt',
          'Omni-bot upstream source and original modified Logger implementation:\n'
          + URL.removesuffix('.git') + '/tree/' + COMMIT + '/0.83/Omnibot\n'
          'Logger originally by Paul Nettle / Fluid Studios; modified by Jeremy Swigart.\n'
          'ETPad private CMake/framework/sandbox adaptations are in scripts/build_omnibot.py.\n')
    write(work / platform / 'result.json', json.dumps(dict(source_url=URL, source_commit=COMMIT,
          gamemonkey_commit=GM_COMMIT, boost_sha256=BOOST_SHA, data_archive_sha256=DATA_SHA,
          platform=platform, framework=str(framework),
          private_patches={name: hashlib.sha256((source / name).read_bytes()).hexdigest()
                           for name in ('Common/CMakeLists.txt', 'ET/CMakeLists.txt', 'Common/FileSystem.cpp')},
          execution_tested=False), indent=2) + '\n')
    return framework


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=('simulator', 'device'), required=True)
    print(build(parser.parse_args().platform))
