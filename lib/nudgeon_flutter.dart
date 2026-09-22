/// NudgeOn Flutter SDK (PRD-01A 3.4). 무상태 브리지 — 네이티브 코어에 MethodChannel
/// 호출 + EventChannel 스트림만 전달한다. 상태는 네이티브 코어에만 (PRD-01A 1.1).
library nudgeon_flutter;

export 'nudgeon_events.dart';
export 'nudgeon_attributes.dart';

import 'dart:async';
import 'package:flutter/services.dart';

/// SDK 설정 (PRD-01A 2.1)
class NudgeOnConfig {
  final String sdkKey;
  final String apiHost; // 셀프호스팅 시 교체
  final String? appGroup;

  /// iOS only. Android core 0.2.2 has no runtime log-level API.
  final String? logLevel;
  final int flushInterval;
  final int flushBatchSize;
  final bool autoTrackSessions;
  final bool autoRegisterPushToken;

  const NudgeOnConfig({
    required this.sdkKey,
    required this.apiHost,
    this.appGroup,
    this.logLevel,
    this.flushInterval = 10,
    this.flushBatchSize = 10,
    this.autoTrackSessions = true,
    this.autoRegisterPushToken = true,
  });

  Map<String, dynamic> toMap() => {
        'sdkKey': sdkKey,
        'apiHost': apiHost,
        if (appGroup != null) 'appGroup': appGroup,
        if (logLevel != null) 'logLevel': logLevel,
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

  /// 리치 알림 이미지 URL — 네이티브 SDK가 표시(iOS NSE 첨부·Android BigPicture)한다.
  final String? imageUrl;
  final Map<String, dynamic> data;

  /// 무음(백그라운드) 푸시. 네이티브가 소비하므로 리스너에는 오지 않는다 — 형태 대칭용.
  final bool silent;

  PushPayload.fromMap(Map<dynamic, dynamic> m)
      : messageId = m['messageId'] as String,
        campaignId = m['campaignId'] as String?,
        journeyId = m['journeyId'] as String?,
        title = (m['title'] ?? '') as String,
        body = (m['body'] ?? '') as String,
        deepLink = m['deepLink'] as String?,
        imageUrl = m['imageUrl'] as String?,
        data = Map<String, dynamic>.from(m['data'] ?? {}),
        silent = (m['silent'] as bool?) ?? false;
}

enum PushPermissionResult { granted, denied, provisional }

/// 구독 상태 (PRD-01A 2.4)
class SubscriptionState {
  final bool serviceOptIn;
  final String osPermission;
  final bool tokenRegistered;

  SubscriptionState.fromMap(Map<dynamic, dynamic> m)
      : serviceOptIn = (m['serviceOptIn'] ?? true) as bool,
        osPermission = (m['osPermission'] ?? 'not_determined') as String,
        tokenRegistered = (m['tokenRegistered'] ?? false) as bool;
}

/// 공개 API — iOS/Android 네이티브 코어 위임 (PRD-01A 2장)
class NudgeOn {
  static const MethodChannel _channel = MethodChannel('io.nudgeon/methods');
  static const EventChannel _events = EventChannel('io.nudgeon/events');

  /// {event, payload} 브로드캐스트 — 구독 시 네이티브 StreamHandler가 버퍼(최대 20건) 재생
  /// (이벤트별 네이티브 버퍼 재생 — Flutter에서 가장 흔히 깨지는 지점, PRD-01A 2.5).
  static final Stream<Map<dynamic, dynamic>> _stream =
      _events.receiveBroadcastStream().cast<Map<dynamic, dynamic>>();

  static final Map<String, Stream<PushPayload>> _typedStreams = {};

  static Stream<PushPayload> _filtered(String event) =>
      _typedStreams.putIfAbsent(event, () {
        late StreamController<PushPayload> controller;
        StreamSubscription<Map<dynamic, dynamic>>? subscription;
        controller = StreamController<PushPayload>.broadcast(
          onListen: () {
            subscription = _stream.where((e) => e['event'] == event).listen(
                  (e) => controller.add(PushPayload.fromMap(
                      e['payload'] as Map<dynamic, dynamic>)),
                  onError: controller.addError,
                );
            // Attach the native event only after its Dart consumer exists. This
            // keeps the other event's cold-start buffer in the native core.
            _channel.invokeMethod<void>(
                'subscribeEvent', {'event': event}).catchError((Object error,
                    StackTrace stack) =>
                controller.addError(error, stack));
          },
          onCancel: () async {
            final previous = subscription;
            subscription = null;
            final stopped = _channel
                .invokeMethod<void>('unsubscribeEvent', {'event': event});
            await previous?.cancel();
            await stopped;
          },
        );
        return controller.stream;
      });

  static Future<void> initialize(NudgeOnConfig config) =>
      _channel.invokeMethod('initialize', config.toMap());

  static Future<void> identify(String externalId) =>
      _channel.invokeMethod('identify', {'externalId': externalId});

  static Future<void> reset() => _channel.invokeMethod('reset');

  static Future<void> setUserAttributes(Map<String, dynamic> attrs) =>
      _channel.invokeMethod('setUserAttributes', {'attrs': attrs});

  static Future<void> track(String name, {Map<String, dynamic>? properties}) =>
      _channel.invokeMethod(
          'track', {'name': name, 'properties': properties ?? {}});

  static Future<void> flush() => _channel.invokeMethod('flush');

  // 푸시
  static Future<PushPermissionResult> registerForPush() async {
    final r = await _channel.invokeMethod<String>('registerForPush');
    return PushPermissionResult.values.firstWhere(
      (e) => e.name == r,
      orElse: () => PushPermissionResult.denied,
    );
  }

  static Future<void> setPushSubscription(bool optedIn) =>
      _channel.invokeMethod('setPushSubscription', {'optedIn': optedIn});

  static Future<SubscriptionState> getPushSubscription() async {
    final m = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('getPushSubscription');
    return SubscriptionState.fromMap(m ?? {});
  }

  // 리스너 (이벤트별 네이티브 버퍼 재생)
  static Stream<PushPayload> get onPushOpened => _filtered('pushOpened');
  static Stream<PushPayload> get onPushReceived => _filtered('pushReceived');

  /// 콜드 스타트 — 푸시로 앱이 열렸으면 payload, 아니면 null (이중 경로).
  static Future<PushPayload?> getInitialPushPayload() async {
    final m = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('getInitialPushPayload');
    return m == null ? null : PushPayload.fromMap(m);
  }

  // 유틸리티
  static Future<String?> getDeviceId() =>
      _channel.invokeMethod<String>('getDeviceId');
  static Future<String?> getAnonId() =>
      _channel.invokeMethod<String>('getAnonId');
  static Future<void> setLogLevel(String level) =>
      _channel.invokeMethod('setLogLevel', {'level': level});
}
