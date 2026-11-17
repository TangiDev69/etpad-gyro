#!/usr/bin/env python3
"""Read-only audit of ETPad Apple exports. Compatible with Apple Python 3.9.

Usage: check-apple-package.py --platform macos|simulator|device PATH
macOS PATH is the exported package directory (containing ET Legacy.app).
iOS PATH is an exported .app, not an IPA. No files are extracted or changed.
"""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import plistlib
import re
import subprocess
import sys
import zipfile


MACH_MAGICS = {b'\xfe\xed\xfa\xce', b'\xce\xfa\xed\xfe',
               b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe',
               b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca',
               b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca'}
FRAMEWORKS = {'ETPadEngine', 'ETPadRenderer', 'ETPadCGame', 'ETPadUI',
              'ETPadGame', 'ETPadOmnibot', 'libEGL', 'libGLESv2'}
VULKAN_FRAMEWORKS = {'ETPadVulkanRenderer', 'MoltenVK'}
ANGLE = {'libEGL', 'libGLESv2'}
SYSTEM_PREFIXES = ('/System/Library/', '/usr/lib/')
INSTALLER_SUFFIXES = ('.run', '.dmg', '.pkg', '.mpkg', '.msi', '.exe',
                      '.zip', '.tar', '.tar.gz', '.tgz', '.tar.bz2', '.7z')
SAVE_SUFFIXES = ('.save', '.sav', '.pid', '.log', '.mobileprovision', '.p12', '.pfx', '.key', '.pem', '.p8')
PRIVATE_NAMES = {'etkey', 'etconfig.cfg', 'setup.sh', 'etkey.sh', 'makekey',
                 'makekey.sh', 'install.sh', 'profiles', 'save', 'saves', 'savegames',
                 'screenshots', 'demos', 'downloads', 'installers', '.git'}


class AuditError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise AuditError(message)


def command(*args):
    result = subprocess.run([str(arg) for arg in args], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True)
    require(result.returncode == 0, '{} failed: {}'.format(
        ' '.join(str(arg) for arg in args), (result.stderr or result.stdout).strip()))
    return result.stdout


def inside(path, root):
    try:
        path.resolve().relative_to(root)
        return True
    except ValueError:
        return False


def forbidden_name(name):
    """Check both ordinary files and archive member paths."""
    normalized = name.replace('\\', '/').lower()
    parts = PurePosixPath(normalized).parts
    if any(part in PRIVATE_NAMES for part in parts):
        return True
    leaf = parts[-1] if parts else ''
    return (leaf in {'pak0.pk3', 'pak1.pk3', 'pak2.pk3'} or
            leaf.endswith(INSTALLER_SUFFIXES + SAVE_SUFFIXES) or
            bool(re.search(r'\.dm_\d+$', leaf)))


def native_kind(header):
    if header[:4] in MACH_MAGICS:
        return 'Mach-O'
    if header.startswith(b'\x7fELF'):
        return 'ELF'
    if header.startswith(b'MZ'):
        return 'PE'
    if header.startswith(b'!<arch>'):
        return 'static archive'
    return None


def stream_hash(stream):
    digest = hashlib.sha256()
    for block in iter(lambda: stream.read(1024 * 1024), b''):
        digest.update(block)
    return digest.digest()


def audit_archive(path, root, own_modules=None):
    label = str(path.relative_to(root))
    own_modules = own_modules or {}
    try:
        with zipfile.ZipFile(path) as archive:
            for item in archive.infolist():
                name = item.filename
                parts = PurePosixPath(name.replace('\\', '/')).parts
                require(not name.startswith(('/', '\\')) and '..' not in parts
                        and not re.match(r'^[A-Za-z]:', name),
                        label + ': unsafe archive path ' + name)
                require(not forbidden_name(name), label + ': private/media/installer member ' + name)
                require(not name.lower().endswith(('.dll', '.dylib', '.so')),
                        label + ': native library member ' + name)
                if not item.is_dir():
                    with archive.open(item) as stream:
                        kind = native_kind(stream.read(8))
                    if kind == 'Mach-O' and name in own_modules:
                        with archive.open(item) as member_stream, own_modules[name].open('rb') as own_stream:
                            require(stream_hash(member_stream) == stream_hash(own_stream),
                                    label + ': native member differs from exported own module ' + name)
                        print('PASS ' + label + ': ' + name + ' matches exported own module exactly')
                    else:
                        require(kind is None, label + ': ' + str(kind) + ' member ' + name)
            require(archive.testzip() is None, label + ': ZIP integrity failure')
    except (zipfile.BadZipFile, RuntimeError) as error:
        raise AuditError(label + ': invalid archive: ' + str(error))


def bundle_executable(bundle, macos=False):
    info = bundle / ('Contents/Info.plist' if macos else 'Info.plist')
    require(info.is_file(), 'Missing bundle metadata: ' + str(info))
    with info.open('rb') as stream:
        name = plistlib.load(stream).get('CFBundleExecutable')
    require(isinstance(name, str) and bool(name) and Path(name).name == name,
            'Invalid bundle executable in ' + str(info))
    binary = bundle / ('Contents/MacOS' if macos else '') / name
    require(binary.is_file(), 'Missing bundle executable: ' + str(binary))
    return binary


def system_path(path):
    return path.startswith(SYSTEM_PREFIXES)


def expand_relative(path, binary, executable):
    for prefix, directory in (('@loader_path', binary.parent),
                              ('@executable_path', executable.parent)):
        if path == prefix or path.startswith(prefix + '/'):
            return directory / path[len(prefix):].lstrip('/')
    return None


def audit_binary(binary, root, app, executable, platform, angle=False):
    label = str(binary.relative_to(root))
    archs = set(command('xcrun', 'lipo', '-archs', binary).split())
    allowed = {'arm64', 'x86_64'} if platform == 'simulator' and angle else {'arm64'}
    require('arm64' in archs and archs <= allowed,
            label + ': unexpected architectures ' + ', '.join(sorted(archs)))
    expected_platform = {'macos': 'MACOS', 'simulator': 'IOSSIMULATOR', 'device': 'IOS'}[platform]
    for arch in sorted(archs):
        output = command('xcrun', 'vtool', '-arch', arch, '-show-build', binary)
        platforms = re.findall(r'^\s*platform\s+(\S+)', output, flags=re.M)
        require(platforms and set(platforms) == {expected_platform},
                label + ': ' + arch + ' platform ' + repr(platforms) + ', expected ' + expected_platform)
    loads = command('otool', '-l', binary)
    rpaths = re.findall(r'cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset \d+\)', loads)
    directories = [app / 'Frameworks', app / 'Contents/Frameworks']
    for rpath in rpaths:
        if system_path(rpath):
            continue
        expanded = expand_relative(rpath, binary, executable)
        require(expanded is not None and inside(expanded, root),
                label + ': non-package runtime search path ' + rpath)
        directories.append(expanded)
    dependencies = command('otool', '-L', binary)
    for dependency in re.findall(r'^\s+(.+?) \(compatibility version ', dependencies, flags=re.M):
        if system_path(dependency):
            continue
        if dependency.startswith('@rpath/'):
            candidates = [directory / dependency[len('@rpath/'):] for directory in directories]
        else:
            expanded = expand_relative(dependency, binary, executable)
            candidates = [expanded] if expanded is not None else []
        require(any(inside(candidate, root) and candidate.is_file() for candidate in candidates),
                label + ': unresolved/non-package dependency ' + dependency)
    print('PASS {}: {} {}, packaged/system dependencies'.format(
        label, '/'.join(sorted(archs)), expected_platform))


def audit(platform, path):
    root = path.expanduser().resolve()
    require(root.is_dir(), 'Expected an exported directory: ' + str(root))
    if platform == 'macos':
        require(root.suffix != '.app', 'For macos, pass the package directory containing ET Legacy.app and legacy/')
        app = root / 'ET Legacy.app'
        executable = bundle_executable(app, macos=True)
        expected = {executable, root / 'librenderer_opengl1_mac'}
        expected.update(root / 'legacy' / name for name in ('cgame_mac', 'ui_mac', 'qagame_mac'))
        legacy = root / 'legacy'
        notices = root / 'Notices'
        require((root / 'COPYING.txt').is_file(), 'Missing package COPYING.txt')
    else:
        require(root.suffix == '.app', 'For iOS, pass the exported .app directory (not the IPA)')
        app = root
        executable = bundle_executable(app)
        expected = {executable}
        frameworks = app / 'Frameworks'
        actual = {item.stem for item in frameworks.glob('*.framework') if item.is_dir()}
        require(FRAMEWORKS <= actual, 'Missing frameworks: ' + ', '.join(sorted(FRAMEWORKS - actual)))
        require(not actual - FRAMEWORKS - VULKAN_FRAMEWORKS,
                'Unexpected frameworks: ' + ', '.join(sorted(actual - FRAMEWORKS - VULKAN_FRAMEWORKS)))
        require(not actual & VULKAN_FRAMEWORKS or VULKAN_FRAMEWORKS <= actual,
                'Vulkan renderer and MoltenVK must be packaged together')
        if actual & VULKAN_FRAMEWORKS:
            require((app / 'Notices/MoltenVK-LICENSE.txt').is_file(), 'Missing MoltenVK license notice')
            for name in ('MoltenVK-LICENSE.txt', 'cereal-LICENSE.txt', 'SPIRV-Cross-LICENSE.txt',
                         'Vulkan-Headers-LICENSE.md', 'Vulkan-Headers-Apache-2.0.txt',
                         'Vulkan-Headers-MIT.txt', 'MoltenVK-copyright.txt',
                         'SPIRV-Cross-copyright.txt', 'SPIRV-Headers-copyright.txt', 'cereal-copyright.txt'):
                require((frameworks / 'MoltenVK.framework/Notices' / name).is_file(),
                        'Missing MoltenVK dependency notice: ' + name)
        for name in sorted(actual):
            framework = frameworks / (name + '.framework')
            with (framework / 'Info.plist').open('rb') as stream:
                metadata = plistlib.load(stream)
            require(bool(metadata.get('CFBundleVersion')), 'Missing framework bundle version: ' + name)
            require(metadata.get('MinimumOSVersion') == '16.0', 'Unexpected minimum OS version: ' + name)
            require(metadata.get('CFBundleSupportedPlatforms') == ['iPhoneSimulator' if platform == 'simulator' else 'iPhoneOS'],
                    'Unexpected framework supported platform: ' + name)
            binary = bundle_executable(framework)
            require(binary.name == name, 'Unexpected framework executable: ' + str(binary))
            expected.add(binary)
        bot = frameworks / 'ETPadOmnibot.framework'
        require((bot / 'et/scripts').is_dir() and (bot / 'et/nav').is_dir()
                and (bot / 'global_scripts').is_dir(), 'Missing bundled bot script/navigation data')
        for name in ('Boost-LICENSE.txt', 'PhysFS-LICENSE.txt', 'GameMonkeyLicense.pdf',
                     'GameMonkey-copyright.h', 'WildMagic-copyright.h', 'zlib-copyright.h', 'zlib-README.txt',
                     'MathLib-copyright.h', 'LZMA-license.txt', 'LZMA-LGPL.txt', 'FSBAllocator-copyright.h',
                     'GameMonkeyBindings-copyright.h', 'KeyValueIni-copyright.cpp', 'Logger-copyright.h',
                     'Bison-skeleton-notice.txt', 'OMNIBOT-SOURCE.txt'):
            require((bot / 'Notices' / name).is_file(), 'Missing bot notice: ' + name)
        legacy = app / 'GameContent/legacy'
        notices = app / 'Notices'
        for name in ('ANGLE-LICENSE.txt', 'GL4ES-LICENSE.txt'):
            require((notices / name).is_file(), 'Missing notice: ' + name)
    require((notices / 'ETLegacy-GPL.txt').is_file(), 'Missing ET: Legacy GPL notice')
    require((legacy / 'etpad-controller.cfg').is_file(), 'Missing controller defaults')
    packs = list(legacy.glob('legacy_*.pk3'))
    require(len(packs) == 1, 'Expected exactly one GPL Legacy mod pack, found ' + str(len(packs)))
    own_modules = ({name: legacy / name for name in ('cgame_mac', 'ui_mac', 'qagame_mac')}
                   if platform == 'macos' else {})
    for binary in expected:
        require(binary.is_file() and inside(binary, root), 'Missing/outside-package binary: ' + str(binary))
    found = set()
    files = 0
    for entry in sorted(root.rglob('*')):
        label = str(entry.relative_to(root))
        require(not forbidden_name(label), 'Private/media/installer path: ' + label)
        if entry.is_symlink():
            require(entry.exists() and inside(entry, root), 'Broken/outside-package symlink: ' + label)
            require(not entry.is_dir(), 'Directory symlink is not supported in these exports: ' + label)
        if not entry.is_file():
            continue
        files += 1
        with entry.open('rb') as stream:
            header = stream.read(8)
        kind = native_kind(header)
        if kind == 'Mach-O':
            require(entry in expected, 'Unexpected native executable/library: ' + label)
            found.add(entry)
        else:
            require(kind is None, 'Unexpected ' + str(kind) + ': ' + label)
            require(not entry.name.lower().endswith(('.dll', '.dylib', '.so')),
                    'Unexpected native library file: ' + label)
        if entry.suffix.lower() == '.pk3':
            require(entry in packs, 'Unexpected data pack: ' + label)
            audit_archive(entry, root, own_modules)
        elif zipfile.is_zipfile(entry):
            require(entry.suffix.lower() == '.xlsx', 'Unexpected archive: ' + label)
            audit_archive(entry, root)
    require(found == expected, 'Expected binaries are not Mach-O: ' + ', '.join(str(p.relative_to(root)) for p in expected - found))
    for binary in sorted(found):
        audit_binary(binary, root, app, executable, platform,
                     angle=binary.parent.stem in ANGLE)
    if platform == 'simulator':
        for framework in sorted((app / 'Frameworks').glob('*.framework')):
            command('codesign', '--verify', '--strict', framework)
        command('codesign', '--verify', '--deep', '--strict', app)
        print('PASS simulator framework and app deep/strict signatures')
    elif platform == 'device':
        print('NOTE device signatures are not required; this audit does not establish installability')
    pack_kind = 'Legacy pack with byte-verified own modules' if platform == 'macos' else 'data-only Legacy pack'
    print('PASS {}: {} Mach-O binaries, {} files, one {}, notices and media boundaries'.format(
        platform, len(found), files, pack_kind))
    print('Read-only package audit passed; runtime/physical-device acceptance is separate.')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--platform', choices=('macos', 'simulator', 'device'), required=True)
    parser.add_argument('path', type=Path)
    args = parser.parse_args()
    try:
        audit(args.platform, args.path)
    except (AuditError, OSError, ValueError, KeyError, plistlib.InvalidFileException) as error:
        print('FAIL: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
