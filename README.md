# onda_flutter

Onda 고객 인게이지먼트 플랫폼 Flutter SDK — 네이티브 코어(iOS/Android) 브리지.

> 상태: **M3 골격**. Federated plugin 구조·공개 Dart API 확정, MethodChannel/EventChannel
> 네이티브 배선은 구현 예정 (코어 API 동결 후 착수 — PRD-01A 6장).

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
final initial = await Onda.getInitialPushPayload(); // 콜드 스타트 처리
```

## 아키텍처 (PRD-01A 1.1 · 3.4)

- **무상태 브리지** — 상태는 네이티브 코어에만. MethodChannel 호출 + EventChannel 스트림.
- Federated plugin: `onda_flutter` / `onda_flutter_ios` / `onda_flutter_android`.

MIT License.
