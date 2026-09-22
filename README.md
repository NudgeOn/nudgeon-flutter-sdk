# nudgeon_flutter

NudgeOn iOS/Android 네이티브 코어를 연결하는 Flutter 플러그인입니다.
이벤트 수집, 사용자 식별, 푸시 구독과 알림 콜백을 Dart에서 사용합니다.

**0.1.3 배포 후보이며 pub.dev 게시 전입니다.** iOS 코어 0.2.2와 Android 코어 0.2.8은
공개 SPM/Git 태그와 Maven Central에서 내려받습니다. CocoaPods trunk 등록도
대기 중이므로 아래 고정 podspec 설정이 필요합니다.


## 기본 사용자 속성 (다음 릴리스)

`NudgeOnAttributes`는 `setUserAttributes`에 전달할 키 상수입니다. 기존 게시 버전에는 없으므로 릴리스 전에는 문자열 키를 사용할 수 있습니다. SDK 초기화 후 `identify`를 먼저 호출하세요. 식별 전 속성 설정은 현재 지원하지 않습니다.

```dart
import 'package:nudgeon_flutter/nudgeon_flutter.dart';

await NudgeOn.identify('user-123');
await NudgeOn.setUserAttributes({
  NudgeOnAttributes.firstName: 'Minji',
  NudgeOnAttributes.email: 'minji@example.com',
  NudgeOnAttributes.dateOfBirth: '1995-03-15',
  NudgeOnAttributes.country: 'KR',
  NudgeOnAttributes.timezone: 'Asia/Seoul',
  'membership_level': 'gold',
});
await NudgeOn.setUserAttributes({NudgeOnAttributes.phone: null});
```

| 상수 | 전송 키 | 예시 |
|---|---|---|
| `NudgeOnAttributes.firstName` | `first_name` | `Minji` |
| `NudgeOnAttributes.lastName` | `last_name` | `Kim` |
| `NudgeOnAttributes.email` | `email` | `minji@example.com` |
| `NudgeOnAttributes.phone` | `phone` | `+821012345678` |
| `NudgeOnAttributes.dateOfBirth` | `dob` | `1995-03-15` |
| `NudgeOnAttributes.gender` | `gender` | `F` |
| `NudgeOnAttributes.homeCity` | `home_city` | `Seoul` |
| `NudgeOnAttributes.country` | `country` | `KR` |
| `NudgeOnAttributes.language` | `language` | `ko` |
| `NudgeOnAttributes.timezone` | `timezone` | `Asia/Seoul` |
| `NudgeOnAttributes.createdAt` | `created_at` | `2026-09-22T00:00:00Z` |

생일은 `YYYY-MM-DD` 문자열, 가입일은 시간대가 있는 RFC 3339 문자열을 사용합니다. 전화번호는 E.164, 국가·언어는 `KR`·`ko` 같은 코드, 시간대는 IANA 이름을 권장합니다. `gender` 권장 코드는 `M`, `F`, `O`, `N`, `P`, `U`입니다. Braze `time_zone`은 기존 NudgeOn 키 `timezone`으로 전달합니다.

값은 자동 수집·변환하지 않으며 커스텀 키도 지원합니다. `null`은 값을 삭제합니다. 현재 속성 전송은 네트워크 요청이며 이벤트 오프라인 큐의 영속 재시도 보장을 제공하지 않습니다. 실패에 대비한 재동기화는 앱에서 수행하세요. 푸시 수신 동의는 `setPushSubscription`을 사용하며 `push_subscribe` 같은 일반 속성으로 변경하지 않습니다.

## 기본 이벤트 (Standard events — 다음 릴리스)

`NudgeOnEvents`로 콘솔과 같은 이벤트 이름을 사용할 수 있습니다. 아래 상수는 이 소스에 추가된 API이며 기존 게시 버전에는 포함되어 있지 않습니다.
SDK를 초기화한 뒤 해당 행동이 성공한 시점에 호출하세요. 예시는 서로 다른 호출 시점을 보여주며, 회원가입·로그인·구입을 한 번에 자동 수집하는 코드는 아닙니다.

```dart
import 'package:nudgeon_flutter/nudgeon_flutter.dart';

// After SDK initialization and your app's authentication succeeds:
await NudgeOn.identify('user-123');
await NudgeOn.track(NudgeOnEvents.signUp, properties: {'method': 'email'});
await NudgeOn.track(NudgeOnEvents.login, properties: {'method': 'email'});
// After order/payment confirmation:
await NudgeOn.track(NudgeOnEvents.purchaseCompleted, properties: {
  'order_id': 'order-123', 'total_amount': 29000, 'currency': 'KRW', 'item_count': 1,
});
```

| 상수 | 전송 이름 | 의미 | 권장 속성 |
|---|---|---|---|
| `NudgeOnEvents.signUp` | `sign_up` | 회원가입 | method |
| `NudgeOnEvents.login` | `login` | 로그인 | method |
| `NudgeOnEvents.purchaseCompleted` | `purchase_completed` | 구입 | order_id, total_amount, currency, item_count |
| `NudgeOnEvents.productViewed` | `product_viewed` | 상품 조회 | product_id, price, currency |
| `NudgeOnEvents.addToCart` | `add_to_cart` | 장바구니 담기 | product_id, quantity, price, currency |
| `NudgeOnEvents.checkoutStarted` | `checkout_started` | 결제 시작 | cart_id, item_count, total_amount, currency |

금액은 통화의 기본 단위(원·달러 등) 숫자, 통화는 ISO 4217 코드(`KRW`, `USD` 등)를 사용합니다. 속성은 권장 예시이며 서비스별 속성도 추가할 수 있습니다.
기존 `track("custom_event", ...)`는 그대로 지원하며 `purchase` 같은 기존 이름을 자동 변환하지 않습니다.
이름은 대소문자까지 콘솔 설정과 같아야 합니다. 상수 참조 자체는 이벤트를 만들지 않고, `login` 이벤트는 사용자 식별을 대신하지 않습니다.
`track` 이후 오프라인 저장·배치·재시도는 기존 전송 경로를 사용합니다.


## 설치

게시 전에는 이 저장소를 로컬 경로 또는 검토한 Git 커밋으로 연결하세요.

```yaml
dependencies:
  nudgeon_flutter:
    path: ../nudgeon-flutter-sdk
```

검증 기준은 Flutter 3.38.4/3.38.5, Dart 3.10, Java 17입니다.
Android 앱의 `minSdk`를 **26 이상**, Kotlin을 **2.1.20 이상**으로 설정하세요.
iOS 앱과 확장 프로그램의 deployment target은 **15.0 이상**입니다.

`ios/Podfile`의 앱 target 안에 다음을 추가하고 `pod install`을 실행하세요.
이 URL의 podspec은 공개 SDK **0.2.2 Git 태그**를 내려받습니다.

```ruby
platform :ios, '15.0'
target 'Runner' do
  pod 'NudgeOnSDK', :podspec => 'https://raw.githubusercontent.com/NudgeOn/nudgeon-ios-sdk/87da4258f7b8cbf27041d6b096815158cc0febee/NudgeOnSDK.podspec'
  # 기존 Flutter 설정 유지
end
```

Xcode 27 / iOS 27에서 구형 Flutter 템플릿을 사용하는 경우
[Flutter UIScene 전환 안내](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)를
적용하세요. `FlutterImplicitEngineDelegate`에서 플러그인을 등록하고
Info.plist에 `FlutterSceneDelegate`를 지정해야 앱 시작 시 종료되지 않습니다.
재현 가능한 설정은 [consumer fixture](tests/consumer/README.md)에 있습니다.

## 빠른 시작

```dart
import 'package:nudgeon_flutter/nudgeon_flutter.dart';

final opened = NudgeOn.onPushOpened.listen((payload) {
  // payload.deepLink를 앱 라우터에서 검증 후 처리합니다.
});
await NudgeOn.initialize(const NudgeOnConfig(
  sdkKey: 'pk_...',
  apiHost: 'https://ingest.example.com',
  autoRegisterPushToken: false,
));
await NudgeOn.identify('user-123');
await NudgeOn.track('product_viewed', properties: {'product_id': 'P-1'});
// 화면/서비스를 해제할 때:
await opened.cancel();
```

`flushInterval`은 양의 정수 초, `flushBatchSize`는 양의 정수 건수입니다.
`appGroup`은 iOS 알림 확장과 공유할 App Group입니다.
`logLevel`/`setLogLevel`은 iOS 전용이며 Android 코어 0.2.8에서는
`E_UNSUPPORTED`를 반환합니다. 공통 초기화 설정에서는 생략하세요.

리스너 등록 전의 콜백은 네이티브 메모리 버퍼(최대 20건)에서 이벤트별로
재생합니다. 프로세스 종료·버퍼 초과에 대한 무손실 보장은 아닙니다.
`getInitialPushPayload()`와 리스너를 함께 사용할 때는 `messageId`로
중복 이동을 막으세요. 여러 Dart 리스너는 하나의 네이티브 EventChannel을
공유하며, 다른 이벤트의 리스너를 취소해도 유지됩니다.

## 푸시 연결

플러그인 설치만으로 APNs/FCM 공급자 설정이 완료되지는 않습니다.
iOS Push Notifications 권한·APNs 토큰/알림 콜백과 Android Firebase 설정,
서비스/intent 연결은 네이티브 설치 가이드를 따르세요.

- [iOS 코어 설치](https://github.com/NudgeOn/nudgeon-ios-sdk/tree/0.2.2)
- [Android 코어 설치](https://github.com/NudgeOn/nudgeon-android-sdk/tree/0.2.8)

앱 화면에서 `registerForPush()`를 호출하세요. Android는 연결된 Activity를
사용하고 권한 결과를 코어에 전달합니다. 사용자 알림 동의와 서버 공급자
설정은 별도로 필요합니다. 이 배포 후보의 검증에는 실제 단말 푸시 발송을
포함하지 않습니다. 인앱 WebView 캠페인 UI는 현재 Dart API에 노출하지 않습니다.

## 검증과 배포 준비

`flutter analyze`, `flutter test`, `swift test`,
`flutter pub publish --dry-run`과 새 iOS/Android 앱 빌드를 수행합니다.
[검증 fixture](tests/consumer/README.md)는 네이티브 콜백만 주입하며 APNs를 발송하지 않습니다.

최초 pub.dev 게시에는 메인테이너 로그인이 필요합니다. 로그인 전에는 태그를
만들거나 publish 워크플로를 실행하지 마세요. 게시 시 최종 main의 CI 성공을
확인하고 `flutter pub publish --dry-run`으로 파일 목록을 검토한 다음
`flutter pub publish`를 실행합니다. 이후 pub.dev에서 GitHub Actions 자동
게시를 설정할 수 있습니다. 게시 후에는 Git/path override를 제거한 새 앱에서
pub.dev 패키지와 CocoaPods/Maven 의존성의 다운로드·빌드를 다시 검증하세요.

Apache License 2.0. See [LICENSE](LICENSE).
