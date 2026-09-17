import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nudgeon_flutter/nudgeon_flutter.dart';

const qa = MethodChannel('io.nudgeon/qa');
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Probe());
}

class Probe extends StatefulWidget {
  const Probe({super.key});
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  String result = 'RUNNING';
  @override
  void initState() {
    super.initState();
    run();
  }

  Future<void> run() async {
    final checks = <String, bool>{};
    final subscriptions = <StreamSubscription<PushPayload>>[];
    try {
      final received = Completer<PushPayload>();
      subscriptions.add(NudgeOn.onPushReceived.listen((p) {
        if (!received.isCompleted) received.complete(p);
      }));
      await NudgeOn.initialize(const NudgeOnConfig(
          sdkKey: 'pk_simulator_fixture',
          apiHost: 'http://127.0.0.1:9',
          flushInterval: 3600,
          flushBatchSize: 1000,
          autoTrackSessions: false,
          autoRegisterPushToken: false));
      final device = await NudgeOn.getDeviceId();
      final anon = await NudgeOn.getAnonId();
      checks['identifiers'] =
          device?.isNotEmpty == true && anon?.isNotEmpty == true;
      await NudgeOn.reset();
      checks['reset_rotates_anon_preserves_device'] =
          await NudgeOn.getAnonId() != anon &&
              await NudgeOn.getDeviceId() == device;
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await qa.invokeMethod('emit', {'event': 'opened', 'id': 'open-$stamp'});
      final opened = Completer<PushPayload>();
      subscriptions.add(NudgeOn.onPushOpened.listen((p) {
        if (!opened.isCompleted) opened.complete(p);
      }));
      checks['opened_buffer_survives_other_event_listener'] =
          (await opened.future.timeout(const Duration(seconds: 5))).messageId ==
              'open-$stamp';
      await qa
          .invokeMethod('emit', {'event': 'received', 'id': 'receive-$stamp'});
      checks['received_listener_before_initialization'] =
          (await received.future.timeout(const Duration(seconds: 5)))
                  .messageId ==
              'receive-$stamp';
      final state = await NudgeOn.getPushSubscription();
      checks['subscription_state'] =
          state.serviceOptIn && !state.tokenRegistered;
      await NudgeOn.setLogLevel('none');
      checks['ios_log_level'] = true;
      final pass = checks.values.every((value) => value);
      result = jsonEncode({
        'outcome': pass ? 'PASS' : 'FAIL',
        'checks': checks,
        'scope': 'simulated native callbacks; no APNs/device push'
      });
    } catch (error) {
      result = jsonEncode(
          {'outcome': 'FAIL', 'checks': checks, 'error': error.toString()});
    } finally {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }
    await qa.invokeMethod('result', result);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      home: Scaffold(
          appBar: AppBar(title: const Text('NudgeOn Flutter bridge')),
          body: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(result))));
}
