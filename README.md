# onda_flutter

Onda 고객 인게이지먼트 플랫폼 Flutter SDK — 네이티브 코어(iOS/Android) 브리지.

> 상태: **M3 브리지 구현**. Dart 레이어(MethodChannel invoke·EventChannel 스트림·콜드스타트 재생) + iOS/Android 네이티브 플러그인.
> Dart 경계 직렬화·파싱은 flutter_test로 검증(dart/flutter 부재로 이 환경 미실행 — CI 검증). 네이티브 배선은 Flutter 앱 통합 테스트 필요.

## 설치 (pub.dev — 예정)

```yaml
dependencies:
  onda_flutter: ^0.1.0
```

## 빠른 시작

```dart
import 'package:onda_flutter/onda_flutter.dart';

await Onda.initialize(OndaConfig(sdkKey: 'pk_...', apiHost: 'https://ingest.example.com'));
await Onda.identify('user-123');
Onda.track('product_viewed', properties: {'product_id': 'P-1', 'price': 12900});

final result = await Onda.registerForPush();

// 리스너 — 콜드 스타트 유실 0 (구독 시 네이티브 버퍼 재생)
Onda.onPushOpened.listen((p) => router.go(p.deepLink));
final initial = await Onda.getInitialPushPayload(); // 이중 경로
```

## 네이티브 배선

- iOS: `ios/Classes/OndaFlutterPlugin.swift`(MethodChannel + EventChannel StreamHandler) — `OndaSDK` 코어 위임.
- Android: `android/.../OndaFlutterPlugin.kt` — `io.onda:onda-android` 코어 위임.
- 브리지 무상태: `io.onda/methods`(invoke) + `io.onda/events`({event,payload} 스트림) (PRD-01A 4장).

## 아키텍처 (PRD-01A 1.1 · 3.4)

- **무상태 브리지** — 상태는 네이티브 코어에만. MethodChannel 호출 + EventChannel 스트림.
- Federated plugin: `onda_flutter` / `onda_flutter_ios` / `onda_flutter_android`.

MIT License.
