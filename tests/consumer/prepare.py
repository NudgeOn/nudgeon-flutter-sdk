#!/usr/bin/env python3
"""Prepare a fresh Flutter consumer. Source paths are local, native SDKs public."""
import pathlib
import shutil
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[2]
app = pathlib.Path(sys.argv[1]).resolve()
if app.exists():
    raise SystemExit(f'Refusing to overwrite {app}')
subprocess.run(['flutter', 'create', '--platforms=ios,android', '--project-name', 'nudgeon_bridge_probe', str(app)], check=True)
pubspec = app / 'pubspec.yaml'
s = pubspec.read_text().replace('dependencies:\n', f'dependencies:\n  nudgeon_flutter:\n    path: "{root}"\n', 1)
pubspec.write_text(s)
subprocess.run(['flutter', 'pub', 'get'], cwd=app, check=True)
android = app / 'android/app/build.gradle.kts'
android.write_text(android.read_text().replace('minSdk = flutter.minSdkVersion', 'minSdk = 26'))
podfile = app / 'ios/Podfile'
s = podfile.read_text().replace("# platform :ios, '13.0'", "platform :ios, '15.0'")
s = s.replace("target 'Runner' do", "target 'Runner' do\n  pod 'NudgeOnSDK', :podspec => 'https://raw.githubusercontent.com/NudgeOn/nudgeon-ios-sdk/87da4258f7b8cbf27041d6b096815158cc0febee/NudgeOnSDK.podspec'")
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
shutil.copy2(root / 'tests/consumer/main.dart', app / 'lib/main.dart')
print(app)
