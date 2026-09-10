# nudgeon_flutter

NudgeOn 고객 인게이지먼트 플랫폼 Flutter SDK — 네이티브 코어(iOS/Android) 브리지.

> 상태: **M3 브리지 구현**. Dart 레이어(MethodChannel invoke·EventChannel 스트림·콜드스타트 재생) + iOS/Android 네이티브 플러그인.
> Dart 경계 직렬화·파싱은 flutter_test로 검증(dart/flutter 부재로 이 환경 미실행 — CI 검증). 네이티브 배선은 Flutter 앱 통합 테스트 필요.

## 설치 (pub.dev — 예정)

```yaml
dependencies:
  nudgeon_flutter: ^0.1.0
```

## 빠른 시작

```dart
import 'package:nudgeon_flutter/nudgeon_flutter.dart';

await NudgeOn.initialize(NudgeOnConfig(sdkKey: 'pk_...', apiHost: 'https://ingest.example.com'));
await NudgeOn.identify('user-123');
NudgeOn.track('product_viewed', properties: {'product_id': 'P-1', 'price': 12900});

final result = await NudgeOn.registerForPush();

// 리스너 — 콜드 스타트 유실 0 (구독 시 네이티브 버퍼 재생)
NudgeOn.onPushOpened.listen((p) => router.go(p.deepLink));
final initial = await NudgeOn.getInitialPushPayload(); // 이중 경로
```

## 네이티브 배선

- iOS: `ios/Classes/NudgeOnFlutterPlugin.swift`(MethodChannel + EventChannel StreamHandler) — `NudgeOnSDK` 코어 위임.
- Android: `android/.../NudgeOnFlutterPlugin.kt` — `io.nudgeon:nudgeon-sdk` 코어 위임.
- 브리지 무상태: `io.nudgeon/methods`(invoke) + `io.nudgeon/events`({event,payload} 스트림) (PRD-01A 4장).

## 아키텍처 (PRD-01A 1.1 · 3.4)

- **무상태 브리지** — 상태는 네이티브 코어에만. MethodChannel 호출 + EventChannel 스트림.
- Federated plugin: `nudgeon_flutter` / `nudgeon_flutter_ios` / `nudgeon_flutter_android`.

## 게시 (메인테이너)

- **최초 1회**는 pub.dev 정책상 수동: Flutter가 있는 머신에서 `flutter pub publish` (게시자 계정 필요). 게시 뒤 pub.dev 패키지 관리 페이지에서 *Automated publishing → GitHub Actions* 를 `NudgeOn/nudgeon-flutter-sdk`, 태그 패턴 `{{version}}` 로 켠다.
- 그 뒤부터는 `pubspec.yaml` 버전을 올려 머지하고 태그 `X.Y.Z`를 푸시하면 **Publish to pub.dev** 워크플로가 OIDC로 게시한다(시크릿 없음). CI는 매 PR에서 `pub publish --dry-run`으로 게시 가능 상태를 확인한다.

Apache License 2.0. See [LICENSE](LICENSE).
