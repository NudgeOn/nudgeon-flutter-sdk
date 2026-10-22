#!/usr/bin/env python3
"""Prepare a fresh Flutter consumer. Source paths are local, native SDKs public."""
import argparse
import pathlib
import shutil
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('destination')
parser.add_argument('--registry', action='store_true', help='Resolve the wrapper and native core only from public registries')
args = parser.parse_args()
app = pathlib.Path(args.destination).resolve()
if app.exists():
    raise SystemExit(f'Refusing to overwrite {app}')
subprocess.run(['flutter', 'create', '--platforms=ios,android', '--project-name', 'nudgeon_bridge_probe', str(app)], check=True)
pubspec = app / 'pubspec.yaml'
version = next(line.split(':', 1)[1].strip() for line in (root / 'pubspec.yaml').read_text().splitlines() if line.startswith('version:'))
dependency = f'  nudgeon_flutter: {version}\n' if args.registry else f'  nudgeon_flutter:\n    path: "{root}"\n'
s = pubspec.read_text().replace('dependencies:\n', 'dependencies:\n' + dependency, 1)
pubspec.write_text(s)
subprocess.run(['flutter', 'pub', 'get'], cwd=app, check=True)
android = app / 'android/app/build.gradle.kts'
android.write_text(android.read_text().replace('minSdk = flutter.minSdkVersion', 'minSdk = 26'))
shutil.copy2(root / 'tests/consumer/main.dart', app / 'lib/main.dart')
if sys.platform != 'darwin':
    print(app)
    raise SystemExit(0)
podfile = app / 'ios/Podfile'
s = podfile.read_text().replace("# platform :ios, '13.0'", "platform :ios, '15.0'")
if not args.registry:
    s = s.replace("target 'Runner' do", "target 'Runner' do\n  pod 'NudgeOnSDK', :podspec => 'https://raw.githubusercontent.com/NudgeOn/nudgeon-ios-sdk/0.2.9/NudgeOnSDK.podspec'")
s = s.replace('flutter_additional_ios_build_settings(target)', "flutter_additional_ios_build_settings(target)\n    target.build_configurations.each { |c| c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0' }")
podfile.write_text(s)
project = app / 'ios/Runner.xcodeproj/project.pbxproj'
project.write_text(project.read_text().replace('IPHONEOS_DEPLOYMENT_TARGET = 13.0;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;'))
# iOS 27 requires scenes; the 3.38 template predates default scene migration.
import plistlib
info = app / 'ios/Runner/Info.plist'
p = plistlib.loads(info.read_bytes())
p['UIApplicationSceneManifest'] = {'UIApplicationSupportsMultipleScenes': False, 'UISceneConfigurations': {'UIWindowSceneSessionRoleApplication': [{'UISceneClassName': 'UIWindowScene', 'UISceneDelegateClassName': 'FlutterSceneDelegate', 'UISceneConfigurationName': 'flutter', 'UISceneStoryboardFile': 'Main'}]}}
info.write_bytes(plistlib.dumps(p))
shutil.copy2(root / 'tests/consumer/AppDelegate.swift', app / 'ios/Runner/AppDelegate.swift')
print(app)
