#!/usr/bin/env python3
"""Build pinned MoltenVK as an embedded iOS framework. Apple Python 3.9."""
import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
VERSION = '1.4.2'
URL = 'https://github.com/KhronosGroup/MoltenVK/archive/refs/tags/v1.4.2.tar.gz'
SHA256 = '6864db532f1dbbdb621a8d0ec13f24edae318fd9269dd3dd0cdff791334bb1cb'


def package_notices(source, cmake_build, framework):
    # Read the actual pinned CPM inputs selected by this configure, including
    # cached builds. Do not guess a revision from whatever caches exist.
    cache = {}
    for line in (cmake_build / 'CMakeCache.txt').read_text().splitlines():
        if not line.startswith(('#', '//')) and ':' in line and '=' in line:
            key, value = line.split('=', 1)
            cache[key.split(':', 1)[0]] = value
    dependencies = {name: Path(cache['CPM_PACKAGE_' + name + '_SOURCE_DIR'])
                    for name in ('cereal', 'SPIRV-Cross', 'Vulkan-Headers')}
    notices = framework / 'Notices'
    notices.mkdir(exist_ok=True)
    files = {
        'MoltenVK-LICENSE.txt': source / 'LICENSE',
        'cereal-LICENSE.txt': dependencies['cereal'] / 'LICENSE',
        'SPIRV-Cross-LICENSE.txt': dependencies['SPIRV-Cross'] / 'LICENSE',
        'Vulkan-Headers-LICENSE.md': dependencies['Vulkan-Headers'] / 'LICENSE.md',
        'Vulkan-Headers-Apache-2.0.txt': dependencies['Vulkan-Headers'] / 'LICENSES/Apache-2.0.txt',
        'Vulkan-Headers-MIT.txt': dependencies['Vulkan-Headers'] / 'LICENSES/MIT.txt',
    }
    for name, path in files.items():
        shutil.copy2(path, notices / name)
    # Apache license texts alone contain placeholders, not author attribution.
    # Preserve upstream leading copyright/license comments from public inputs.
    headers = {
        'MoltenVK-copyright.txt': source / 'MoltenVK/MoltenVK/GPUObjects/MVKPipeline.mm',
        'SPIRV-Cross-copyright.txt': dependencies['SPIRV-Cross'] / 'spirv_cross.hpp',
        'SPIRV-Headers-copyright.txt': dependencies['SPIRV-Cross'] / 'spirv.hpp',
        'cereal-copyright.txt': dependencies['cereal'] / 'include/cereal/archives/binary.hpp',
    }
    for name, path in headers.items():
        text = path.read_text()
        prefix = re.match(r'\A(?:\s|//[^\n]*(?:\n|$)|/\*[\s\S]*?\*/)*', text).group(0)
        if 'copyright' not in prefix.lower():
            raise RuntimeError('Missing dependency attribution: ' + str(path))
        (notices / name).write_text(prefix.strip() + '\n')
    for name, directory in [('MoltenVK', source), *dependencies.items()]:
        for filename in ('NOTICE', 'NOTICE.txt'):
            path = directory / filename
            if path.is_file():
                shutil.copy2(path, notices / (name + '-' + filename))


def build(platform):
    base = ROOT / 'build/dependencies/moltenvk'
    base.mkdir(parents=True, exist_ok=True)
    archive = base / ('v' + VERSION + '.tar.gz')
    if not archive.exists():
        temporary = archive.with_suffix('.download')
        urllib.request.urlretrieve(URL, temporary)
        if hashlib.sha256(temporary.read_bytes()).hexdigest() != SHA256:
            raise RuntimeError('MoltenVK archive hash mismatch')
        temporary.replace(archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        raise RuntimeError('MoltenVK archive hash mismatch')
    source = base / ('MoltenVK-' + VERSION)
    if not source.exists():
        with tarfile.open(archive) as tar:
            for entry in tar.getmembers():
                path = Path(entry.name)
                if path.is_absolute() or '..' in path.parts:
                    raise RuntimeError('Unsafe MoltenVK archive path')
            tar.extractall(base)
    # Upstream's CMake dependency list is macOS-only; keep this small iOS
    # adaptation in the downloaded build copy, never in pristine ETL libs.
    common = source / 'Common/CMakeLists.txt'
    original = common.read_text()
    patched = original.replace('find_library(APPKIT_LIBRARY AppKit REQUIRED)',
                               'find_library(APPKIT_LIBRARY UIKit REQUIRED)')
    patched = patched.replace('find_library(IOKIT_LIBRARY IOKit REQUIRED)',
                              'find_library(IOKIT_LIBRARY CoreGraphics REQUIRED)')
    if patched != original:
        common.write_text(patched)
    sdkname = 'iphonesimulator' if platform == 'simulator' else 'iphoneos'
    sdk = subprocess.check_output(['xcrun', '--sdk', sdkname, '--show-sdk-path'], text=True).strip()
    out = base / platform
    jobs = max(1, int(subprocess.check_output(['sysctl', '-n', 'hw.ncpu'])) // 2)
    env = dict(os.environ, SDKROOT=sdk, CMAKE_BUILD_PARALLEL_LEVEL=str(jobs))
    subprocess.run(['cmake', '-S', str(source), '-B', str(out / 'cmake'), '-G', 'Ninja',
                    '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_SYSTEM_NAME=iOS',
                    '-DCMAKE_OSX_ARCHITECTURES=arm64', '-DCMAKE_OSX_SYSROOT=' + sdk,
                    '-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0',
                    '-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY',
                    '-DMVK_EXCLUDE_SPIRV_TOOLS=ON',
                    '-DCPM_SOURCE_CACHE=' + str(base / 'cpm')], env=env, check=True)
    subprocess.run(['cmake', '--build', str(out / 'cmake'), '-j' + str(jobs)], env=env, check=True)
    framework = out / 'MoltenVK.framework'
    framework.mkdir(parents=True, exist_ok=True)
    binary = framework / 'MoltenVK'
    shutil.copy2(out / 'cmake/MoltenVK/libMoltenVK.1.4.2.dylib', binary)
    subprocess.run(['install_name_tool', '-id', '@rpath/MoltenVK.framework/MoltenVK', str(binary)], check=True)
    with (framework / 'Info.plist').open('wb') as file:
        plistlib.dump(dict(CFBundleIdentifier='com.etpad.MoltenVK', CFBundleExecutable='MoltenVK',
                           CFBundleName='MoltenVK', CFBundlePackageType='FMWK',
                           CFBundleShortVersionString=VERSION, CFBundleVersion=VERSION,
                           MinimumOSVersion='16.0',
                           CFBundleSupportedPlatforms=['iPhoneSimulator' if platform == 'simulator' else 'iPhoneOS']), file)
    shutil.copy2(source / 'LICENSE', framework / 'LICENSE')
    package_notices(source, out / 'cmake', framework)
    return framework


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['simulator', 'device'], required=True)
    print(build(parser.parse_args().platform))
