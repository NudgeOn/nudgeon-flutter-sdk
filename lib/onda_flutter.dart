/// Onda Flutter SDK (PRD-01A 3.4). 무상태 브리지 — 네이티브 코어에 MethodChannel
/// 호출 + EventChannel 스트림만 전달한다. 상태는 네이티브 코어에만 (PRD-01A 1.1).
///
/// 상태: M3 골격 (코어 API 동결 후 착수). MethodChannel 배선은 구현 예정.
library onda_flutter;

import 'dart:async';
import 'package:flutter/services.dart';

/// SDK 설정 (PRD-01A 2.1)
class OndaConfig {
  final String sdkKey;
  final String apiHost; // 셀프호스팅 시 교체
  final int flushInterval;
  final int flushBatchSize;
  final bool autoTrackSessions;
  final bool autoRegisterPushToken;

  const OndaConfig({
    required this.sdkKey,
    required this.apiHost,
    this.flushInterval = 10,
    this.flushBatchSize = 10,
    this.autoTrackSessions = true,
    this.autoRegisterPushToken = true,
  });

  Map<String, dynamic> toMap() => {
        'sdkKey': sdkKey,
        'apiHost': apiHost,
        'flushInterval': flushInterval,
        'flushBatchSize': flushBatchSize,
        'autoTrackSessions': autoTrackSessions,
        'autoRegisterPushToken': autoRegisterPushToken,
      };
}

/// 푸시 페이로드 (PRD-01A 2.5)
class PushPayload {
  final String messageId;
  final String? campaignId;
  final String? journeyId;
  final String title;
  final String body;
  final String? deepLink;
  final Map<String, dynamic> data;

  PushPayload.fromMap(Map<dynamic, dynamic> m)
      : messageId = m['messageId'] as String,
        campaignId = m['campaignId'] as String?,
        journeyId = m['journeyId'] as String?,
        title = (m['title'] ?? '') as String,
        body = (m['body'] ?? '') as String,
        deepLink = m['deepLink'] as String?,
        data = Map<String, dynamic>.from(m['data'] ?? {});
}

enum PushPermissionResult { granted, denied, provisional }

/// 공개 API — iOS/Android와 완전 동형 (PRD-01A 2장)
class Onda {
  static const MethodChannel _channel = MethodChannel('io.onda/methods');

  static Future<void> initialize(OndaConfig config) =>
      _channel.invokeMethod('initialize', config.toMap());

  static Future<void> identify(String externalId) =>
      _channel.invokeMethod('identify', {'externalId': externalId});

  static Future<void> reset() => _channel.invokeMethod('reset');

  static Future<void> setUserAttributes(Map<String, dynamic> attrs) =>
      _channel.invokeMethod('setUserAttributes', {'attrs': attrs});

  static Future<void> track(String name, {Map<String, dynamic>? properties}) =>
      _channel.invokeMethod('track', {'name': name, 'properties': properties ?? {}});

  static Future<void> flush() => _channel.invokeMethod('flush');

  static Future<PushPermissionResult> registerForPush() async {
    final r = await _channel.invokeMethod<String>('registerForPush');
    return PushPermissionResult.values.firstWhere(
      (e) => e.name == r,
      orElse: () => PushPermissionResult.denied,
    );
  }

  static Future<void> setPushSubscription(bool optedIn) =>
      _channel.invokeMethod('setPushSubscription', {'optedIn': optedIn});

  /// 콜드 스타트 — 푸시로 앱이 열렸으면 payload, 아니면 null (유실 0 요구, PRD-01A 3.4)
  static Future<PushPayload?> getInitialPushPayload() async {
    final m = await _channel.invokeMethod<Map<dynamic, dynamic>>('getInitialPushPayload');
    return m == null ? null : PushPayload.fromMap(m);
  }

  // onPushOpened 스트림(EventChannel)은 M3 구현
}
