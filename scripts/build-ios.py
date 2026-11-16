#!/usr/bin/env python3
"""Build the native UIKit app and its bundled engine frameworks. Apple Python 3.9."""
import argparse
import os
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
    if args.ipa and args.platform != 'device': parser.error('--ipa requires device platform')
    jobs = max(1, int(subprocess.check_output(['sysctl','-n','hw.ncpu'])) // 2)
    sdkname = 'iphonesimulator' if args.platform == 'simulator' else 'iphoneos'
    sdk = subprocess.check_output(['xcrun','--sdk',sdkname,'--show-sdk-path'],text=True).strip()
    engine = ROOT/'build'/('ios-engine-sim' if args.platform=='simulator' else 'ios-engine-device')
    engine.mkdir(parents=True,exist_ok=True)
    env = dict(os.environ, SDKROOT=sdk, CMAKE_BUILD_PARALLEL_LEVEL=str(jobs))
    inputs(args.platform)
    run('/usr/bin/python3','scripts/build-gl4es.py','--platform',args.platform,env=env)
    run('cmake','-S',ROOT,'-B',engine,'-G','Ninja','-DCMAKE_BUILD_TYPE=Release',
        '-DCMAKE_SYSTEM_NAME=iOS','-DCMAKE_SYSTEM_PROCESSOR=arm64','-DCMAKE_OSX_ARCHITECTURES=arm64',
        '-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0','-DCMAKE_OSX_SYSROOT='+sdk,'-DXCODE_SDK_PATH='+sdk,
        '-DBUILD_SERVER=OFF','-DINSTALL_EXTRA=OFF','-DFEATURE_RENDERER1=OFF','-DFEATURE_RENDERER_GLES=ON',
        '-DFEATURE_AUTOUPDATE=OFF','-DFEATURE_OPENAL=OFF','-DFEATURE_CURL=OFF','-DFEATURE_SSL=OFF',
        '-DFEATURE_AUTH=OFF','-DFEATURE_LUA=OFF','-DFEATURE_OMNIBOT=OFF',
        '-DGLES_INCLUDE_DIR='+str(ROOT/'build/gl4es/source/include'),
        '-DGLES_LIBRARY='+str(ROOT/'build/gl4es'/args.platform/'lib/libGL.a'),env=env)
    for target in (engine/'etpad-external-targets.txt').read_text().splitlines():
        run('cmake','--build',engine,'--target',target,'-j'+str(jobs),env=env)
    run('cmake','--build',engine,'--target','etl','renderer_es','cgame','ui','qagame','mod_pk3','-j'+str(jobs),env=env)
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
    run('xcodegen','generate','--spec','apple/ios/Host/project.yml','--project',project,'--project-root',project,env=env)
    destination='generic/platform=iOS Simulator' if args.platform=='simulator' else 'generic/platform=iOS'
    signing=['CODE_SIGN_IDENTITY=-','CODE_SIGNING_ALLOWED=YES'] if args.platform=='simulator' else ['CODE_SIGNING_ALLOWED=NO']
    derived=ROOT/('build/DerivedData-ETPad-'+args.platform)
    run('xcodebuild','-project',project/'ETPad.xcodeproj','-scheme','ETPad','-configuration','Release',
        '-sdk',sdkname,'-destination',destination,'-derivedDataPath',derived,'-jobs',jobs,*signing,'build',env=env)
    app=derived/'Build/Products'/('Release-'+sdkname)/'ETPad.app'
    if args.platform=='simulator': run('codesign','--verify','--deep','--strict',app)
    args.output.mkdir(parents=True,exist_ok=True)
    exported=args.output/('ETPad-'+args.platform+'.app')
    copytree(app,exported)
    if args.zip:
        args.zip.parent.mkdir(parents=True,exist_ok=True)
        run('ditto','-c','-k','--keepParent',exported,args.zip)
    if args.ipa:
        payload=ROOT/'build/ipa-stage/Payload';payload.mkdir(parents=True,exist_ok=True)
        copytree(app,payload/'ETPad.app')
        args.ipa.parent.mkdir(parents=True,exist_ok=True)
        run('ditto','-c','-k','--keepParent',payload,args.ipa)
    print('Experimental app: '+str(exported))
    if args.platform=='device': print('Unsigned device build: requires signing before installation; device not tested.')
if __name__=='__main__': main()
