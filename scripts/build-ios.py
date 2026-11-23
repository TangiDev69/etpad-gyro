#!/usr/bin/env python3
"""Build the native UIKit app and its bundled engine frameworks. Apple Python 3.9."""
import argparse
import os
import plistlib
from pathlib import Path
import shutil
import subprocess
from angle_backend_inputs import inputs, ROOT as ANGLE_ROOT

ROOT = Path(__file__).resolve().parents[1]
def run(*args, env=None):
    subprocess.run([str(x) for x in args], cwd=ROOT, env=env, check=True)
def copytree(source, target):
    if target.exists(): shutil.rmtree(target)
    shutil.copytree(source, target, symlinks=True)
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=('device','simulator'), required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ipa', type=Path)
    parser.add_argument('--zip', type=Path)
    args = parser.parse_args()
    renderer = os.environ.get('ETPAD_RENDERER', 'angle')
    if renderer not in ('angle', 'vulkan'): parser.error('ETPAD_RENDERER must be angle or vulkan')
    if args.ipa and args.platform != 'device': parser.error('--ipa requires device platform')
    # Keep peak memory bounded on hosted macOS runners. The workflow sets this
    # to 2; local builders may opt into a different positive value.
    jobs = max(1, int(os.environ.get('ETPAD_BUILD_JOBS', '2')))
    sdkname = 'iphonesimulator' if args.platform == 'simulator' else 'iphoneos'
    sdk = subprocess.check_output(['xcrun','--sdk',sdkname,'--show-sdk-path'],text=True).strip()
    variant = '-vulkan' if renderer == 'vulkan' else ''
    engine = ROOT/'build'/(('ios-engine-sim' if args.platform=='simulator' else 'ios-engine-device')+variant)
    engine.mkdir(parents=True,exist_ok=True)
    env = dict(os.environ, SDKROOT=sdk, CMAKE_BUILD_PARALLEL_LEVEL=str(jobs))
    inputs(args.platform)
    from build_omnibot import build as build_omnibot
    omnibot = build_omnibot(args.platform)
    moltenvk = None
    if renderer == 'vulkan':
        from build_moltenvk import build as build_moltenvk
        moltenvk = build_moltenvk(args.platform)
    run('/usr/bin/python3','scripts/build-gl4es.py','--platform',args.platform,env=env)
    run('cmake','-S',ROOT,'-B',engine,'-G','Ninja','-DCMAKE_BUILD_TYPE=Release',
        '-DCMAKE_SYSTEM_NAME=iOS','-DCMAKE_SYSTEM_PROCESSOR=arm64','-DCMAKE_OSX_ARCHITECTURES=arm64',
        '-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0','-DCMAKE_OSX_SYSROOT='+sdk,'-DXCODE_SDK_PATH='+sdk,
        '-DBUILD_SERVER=OFF','-DINSTALL_EXTRA=OFF','-DFEATURE_RENDERER1=OFF','-DFEATURE_RENDERER_GLES=ON',
        '-DFEATURE_RENDERER_VULKAN='+('ON' if renderer=='vulkan' else 'OFF'),'-DBUNDLED_MOLTENVK=OFF',
        '-DPython3_EXECUTABLE=/usr/bin/python3',
        '-DFEATURE_AUTOUPDATE=OFF','-DFEATURE_OPENAL=OFF','-DFEATURE_CURL=OFF','-DFEATURE_SSL=OFF',
        '-DFEATURE_AUTH=OFF','-DFEATURE_LUA=OFF','-DFEATURE_OMNIBOT=ON','-DFORCE_OMNIBOT=ON','-DINSTALL_OMNIBOT=OFF',
        '-DGLES_INCLUDE_DIR='+str(ROOT/'build/gl4es/source/include'),
        '-DGLES_LIBRARY='+str(ROOT/'build/gl4es'/args.platform/'lib/libGL.a'),env=env)
    for target in (engine/'etpad-external-targets.txt').read_text().splitlines():
        target_env = env
        if target == 'shaderc_project':
            host_sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
            target_env=dict(env,SDKROOT=host_sdk)
        run('cmake','--build',engine,'--target',target,'-j'+str(jobs),env=target_env)
    targets=['etl','renderer_es','cgame','ui','qagame','mod_pk3']
    if renderer=='vulkan':targets.append('renderer_vulkan')
    run('cmake','--build',engine,'--target',*targets,'-j'+str(jobs),env=env)
    # CMake's generic framework template leaves Apple version/platform fields
    # empty. Complete our private frameworks before Xcode embeds and signs them.
    for framework in [*sorted((engine/'frameworks').glob('ETPad*.framework')),omnibot]:
        info=framework/'Info.plist'
        metadata=plistlib.loads(info.read_bytes())
        metadata.update(CFBundleShortVersionString='0.1',CFBundleVersion='1',
                        MinimumOSVersion='16.0',
                        CFBundleSupportedPlatforms=['iPhoneSimulator' if args.platform=='simulator' else 'iPhoneOS'])
        info.write_bytes(plistlib.dumps(metadata))
    content=ROOT/'build/ios-host-content'
    legacy=content/'GameContent/legacy'
    legacy.mkdir(parents=True,exist_ok=True)
    for stale in legacy.glob('legacy_*.pk3'): stale.unlink()
    shutil.copy2(engine/(engine/'etpad-mod-pack.txt').read_text().strip(),legacy)
    shutil.copy2(ROOT/'apple/shared/etpad-controller.cfg',legacy)
    notices=content/'Notices';notices.mkdir(exist_ok=True)
    run('/usr/bin/python3','scripts/prepare-notices.py','--build-dir',engine,'--platform',args.platform,'--output',notices)
    project=ROOT/'build/ios-host-project';project.mkdir(exist_ok=True)
    env.update(ETPAD_ROOT=str(ROOT),ETPAD_ENGINE_DIR=str(engine))
    spec=ROOT/'apple/ios/Host/project.yml'
    dependencies='      - framework: '+str(omnibot)+'\n        embed: true\n'
    if moltenvk:
        shutil.copy2(moltenvk/'LICENSE',notices/'MoltenVK-LICENSE.txt')
        dependencies+='      - framework: '+str(engine/'frameworks/ETPadVulkanRenderer.framework')+'\n        embed: true\n'
        dependencies+='      - framework: '+str(moltenvk)+'\n        embed: true\n'
    generated=spec.read_text().replace('    dependencies:\n','    dependencies:\n'+dependencies)
    spec=project/('project'+variant+'.yml');spec.write_text(generated)
    run('xcodegen','generate','--spec',spec,'--project',project,'--project-root',project,env=env)
    destination='generic/platform=iOS Simulator' if args.platform=='simulator' else 'generic/platform=iOS'
    signing=['CODE_SIGN_IDENTITY=-','CODE_SIGNING_ALLOWED=YES'] if args.platform=='simulator' else ['CODE_SIGNING_ALLOWED=NO']
    # Optional personal install: ETPAD_TEAM=<team id> signs the device app with
    # Xcode's automatic development signing (ETPAD_BUNDLE_ID overrides the ID).
    team=os.environ.get('ETPAD_TEAM','')
    if team and args.platform=='device':
        signing=['-allowProvisioningUpdates','DEVELOPMENT_TEAM='+team,'CODE_SIGN_STYLE=Automatic','CODE_SIGNING_ALLOWED=YES']
        if os.environ.get('ETPAD_BUNDLE_ID'): signing.append('PRODUCT_BUNDLE_IDENTIFIER='+os.environ['ETPAD_BUNDLE_ID'])
    derived=ROOT/('build/DerivedData-ETPad-'+args.platform+variant)
    run('xcodebuild','-project',project/'ETPad.xcodeproj','-scheme','ETPad','-configuration','Release',
        '-sdk',sdkname,'-destination',destination,'-derivedDataPath',derived,'-jobs',jobs,*signing,'build',env=env)
    app=derived/'Build/Products'/('Release-'+sdkname)/'ETPad.app'
    if args.platform=='simulator': run('codesign','--verify','--deep','--strict',app)
    args.output.mkdir(parents=True,exist_ok=True)
    exported=args.output/('ETPad-'+args.platform+variant+'.app')
    copytree(app,exported)
    run('/usr/bin/python3','scripts/check-apple-package.py','--platform',args.platform,exported,*(['--allow-development-profile'] if team and args.platform=='device' else []))
    if args.zip:
        args.zip.parent.mkdir(parents=True,exist_ok=True)
        run('ditto','-c','-k','--keepParent',exported,args.zip)
    if args.ipa and team: parser.error('--ipa is for unsigned public packages; omit ETPAD_TEAM')
    if args.ipa:
        stage=ROOT/'build/ipa-stage'
        if stage.exists(): shutil.rmtree(stage)
        payload=stage/'Payload';payload.mkdir(parents=True)
        copytree(app,payload/'ETPad.app')
        args.ipa.parent.mkdir(parents=True,exist_ok=True)
        run('ditto','-c','-k','--norsrc','--keepParent',payload,args.ipa)
    print('Experimental app: '+str(exported))
    if args.platform=='device' and not team: print('Unsigned device build: requires signing before installation.')
    if args.platform=='device' and team: print('Development-signed device build for team '+team+'. Install: xcrun devicectl device install app --device <UDID> '+str(exported))
if __name__=='__main__': main()
