package io.nudgeon.flutter

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.nudgeon.sdk.NudgeOn
import io.nudgeon.sdk.NudgeOnConfig
import io.nudgeon.sdk.PushPayload
import java.util.UUID

/**
 * Flutter 브리지 (Android) — 무상태. MethodChannel 호출을 io.nudgeon.sdk 코어로 위임하고,
 * EventChannel로 pushOpened/received를 스트리밍한다 (PRD-01A 3.4·4장).
 */
class NudgeOnFlutterPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var methods: MethodChannel
  private lateinit var events: EventChannel
  private lateinit var appContext: Context
  private var sink: EventChannel.EventSink? = null
  private var openedToken: UUID? = null
  private var receivedToken: UUID? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    methods = MethodChannel(binding.binaryMessenger, "io.nudgeon/methods").apply { setMethodCallHandler(this@NudgeOnFlutterPlugin) }
    events = EventChannel(binding.binaryMessenger, "io.nudgeon/events").apply { setStreamHandler(this@NudgeOnFlutterPlugin) }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methods.setMethodCallHandler(null)
    events.setStreamHandler(null)
  }

  // EventChannel — 구독 시 코어 EventBus가 버퍼(최대 20건) 재생 (콜드 스타트 유실 0)
  override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
    this.sink = sink
    openedToken = NudgeOn.onPushOpened { forward("pushOpened", it) }
    receivedToken = NudgeOn.onPushReceived { forward("pushReceived", it) }
  }

  override fun onCancel(arguments: Any?) {
    openedToken?.let { NudgeOn.off(it) }
    receivedToken?.let { NudgeOn.off(it) }
    sink = null
  }

  private fun forward(event: String, p: PushPayload) {
    sink?.success(mapOf("event" to event, "payload" to payloadMap(p)))
  }

  override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "initialize" -> {
        NudgeOn.initialize(
          appContext,
          NudgeOnConfig(sdkKey = call.argument("sdkKey") ?: "", apiHost = call.argument("apiHost") ?: ""),
        )
        result.success(null)
      }
      "identify" -> { NudgeOn.identify(call.argument("externalId") ?: ""); result.success(null) }
      "reset" -> { NudgeOn.reset(); result.success(null) }
      "setUserAttributes" -> { NudgeOn.setUserAttributes(call.argument("attrs") ?: emptyMap()); result.success(null) }
      "track" -> {
        NudgeOn.track(call.argument("name") ?: "", call.argument("properties") ?: emptyMap())
        result.success(null)
      }
      "flush" -> { NudgeOn.flush(); result.success(null) }
      "setPushSubscription" -> { NudgeOn.setPushSubscription(call.argument("optedIn") ?: true); result.success(null) }
      "setLogLevel" -> result.success(null)
      "getDeviceId" -> result.success(NudgeOn.getDeviceId())
      "getAnonId" -> result.success(NudgeOn.getAnonId())
      "getInitialPushPayload" -> result.success(NudgeOn.getInitialPushPayload()?.let { payloadMap(it) })
      "registerForPush" -> NudgeOn.registerForPush(null) { r -> result.success(r.name.lowercase()) }
      "getPushSubscription" -> {
        val s = NudgeOn.getPushSubscription()
        result.success(
          mapOf(
            "serviceOptIn" to s.serviceOptIn,
            "osPermission" to s.osPermission,
            "tokenRegistered" to s.tokenRegistered,
          ),
        )
      }
      else -> result.notImplemented()
    }
  }

  private fun payloadMap(p: PushPayload): Map<String, Any?> = buildMap {
    put("messageId", p.messageId)
    p.campaignId?.let { put("campaignId", it) }
    p.journeyId?.let { put("journeyId", it) }
    put("title", p.title)
    put("body", p.body)
    p.deepLink?.let { put("deepLink", it) }
    p.imageUrl?.let { put("imageUrl", it) }
    put("silent", p.silent)
    put("data", p.data)
  }
}
