# Fresh native consumer

`python3 tests/consumer/prepare.py /tmp/nudgeon-flutter-consumer-unique`
creates a new Flutter app (never overwrites a directory). CI uses Flutter 3.38.5;
local validation used 3.38.4. Android minSdk is 26; iOS deployment target is 15.
The source plugin is local; native core 0.2.2 resolves from Maven Central and the
public iOS Git tag using an immutable podspec URL (CocoaPods trunk pending).

CI builds Android arm64 debug and iOS arm64 simulator apps. `swift test` covers
Swift value/config conversion; `flutter test` covers the Dart/channel contract.

The generated iOS app also runs a callback fixture when launched. It writes
`Documents/bridge-result.json`. It verifies identifiers, reset, pre-initialization
listeners, event-specific buffer replay and subscription state. Its native QA
channel injects SDK callbacks only: no APNs registration, provider send, or device
push. The fixture uses loopback port 9 and disables automatic sessions/token
registration. A successful compile alone is not a runtime PASS.

The fixture adopts Flutter's UIScene lifecycle for iOS 27:
https://docs.flutter.dev/release/breaking-changes/uiscenedelegate
Its QA channel and synthetic key must not be copied into a production app.
