// 브리지 경계 테스트 (PRD-01A 8장 DoD: 직렬화·이벤트 스트림 경계 100%).
// MethodChannel을 목으로 대체 — Dart 레이어 직렬화·페이로드 파싱만 검증한다.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda_flutter/onda_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('io.onda/methods');
  final calls = <MethodCall>[];
  dynamic reply;

  setUp(() {
    calls.clear();
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('track 인자를 맵으로 직렬화해 invoke', () async {
    await Onda.track('product_viewed', properties: {'product_id': 'P-1', 'price': 12900});
    expect(calls.single.method, 'track');
    expect(calls.single.arguments, {
      'name': 'product_viewed',
      'properties': {'product_id': 'P-1', 'price': 12900},
    });
  });

  test('initialize는 config 맵 전달', () async {
    await Onda.initialize(const OndaConfig(sdkKey: 'pk', apiHost: 'https://h'));
    expect(calls.single.arguments['sdkKey'], 'pk');
    expect(calls.single.arguments['apiHost'], 'https://h');
  });

  test('registerForPush 문자열 결과를 enum으로 파싱', () async {
    reply = 'granted';
    expect(await Onda.registerForPush(), PushPermissionResult.granted);
    reply = 'nonsense';
    expect(await Onda.registerForPush(), PushPermissionResult.denied); // fallback
  });

  test('getInitialPushPayload 맵을 PushPayload로 파싱', () async {
    reply = {'messageId': 'm1', 'title': 't', 'body': 'b', 'data': {'k': 'v'}};
    final p = await Onda.getInitialPushPayload();
    expect(p?.messageId, 'm1');
    expect(p?.data['k'], 'v');
  });

  test('getInitialPushPayload null이면 null', () async {
    reply = null;
    expect(await Onda.getInitialPushPayload(), isNull);
  });

  test('getPushSubscription 맵 파싱', () async {
    reply = {'serviceOptIn': true, 'osPermission': 'authorized', 'tokenRegistered': false};
    final s = await Onda.getPushSubscription();
    expect(s.serviceOptIn, true);
    expect(s.osPermission, 'authorized');
    expect(s.tokenRegistered, false);
  });
}
