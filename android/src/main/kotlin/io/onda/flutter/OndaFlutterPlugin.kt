package io.onda.flutter

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.onda.sdk.Onda
import io.onda.sdk.OndaConfig
import io.onda.sdk.PushPayload
import java.util.UUID

/**
 * Flutter 브리지 (Android) — 무상태. MethodChannel 호출을 io.onda.sdk 코어로 위임하고,
 * EventChannel로 pushOpened/received를 스트리밍한다 (PRD-01A 3.4·4장).
 */
class OndaFlutterPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var methods: MethodChannel
  private lateinit var events: EventChannel
  private lateinit var appContext: Context
  private var sink: EventChannel.EventSink? = null
  private var openedToken: UUID? = null
  private var receivedToken: UUID? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    methods = MethodChannel(binding.binaryMessenger, "io.onda/methods").apply { setMethodCallHandler(this@OndaFlutterPlugin) }
    events = EventChannel(binding.binaryMessenger, "io.onda/events").apply { setStreamHandler(this@OndaFlutterPlugin) }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methods.setMethodCallHandler(null)
    events.setStreamHandler(null)
  }

  // EventChannel — 구독 시 코어 EventBus가 버퍼(최대 20건) 재생 (콜드 스타트 유실 0)
  override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
    this.sink = sink
    openedToken = Onda.onPushOpened { forward("pushOpened", it) }
    receivedToken = Onda.onPushReceived { forward("pushReceived", it) }
  }

  override fun onCancel(arguments: Any?) {
    openedToken?.let { Onda.off(it) }
    receivedToken?.let { Onda.off(it) }
    sink = null
  }

  private fun forward(event: String, p: PushPayload) {
    sink?.success(mapOf("event" to event, "payload" to payloadMap(p)))
  }

  override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "initialize" -> {
        Onda.initialize(
          appContext,
          OndaConfig(sdkKey = call.argument("sdkKey") ?: "", apiHost = call.argument("apiHost") ?: ""),
        )
        result.success(null)
      }
      "identify" -> { Onda.identify(call.argument("externalId") ?: ""); result.success(null) }
      "reset" -> { Onda.reset(); result.success(null) }
      "setUserAttributes" -> { Onda.setUserAttributes(call.argument("attrs") ?: emptyMap()); result.success(null) }
      "track" -> {
        Onda.track(call.argument("name") ?: "", call.argument("properties") ?: emptyMap())
        result.success(null)
      }
      "flush" -> { Onda.flush(); result.success(null) }
      "setPushSubscription" -> { Onda.setPushSubscription(call.argument("optedIn") ?: true); result.success(null) }
      "setLogLevel" -> result.success(null)
      "getDeviceId" -> result.success(Onda.getDeviceId())
      "getAnonId" -> result.success(Onda.getAnonId())
      "getInitialPushPayload" -> result.success(Onda.getInitialPushPayload()?.let { payloadMap(it) })
      "registerForPush" -> Onda.registerForPush(null) { r -> result.success(r.name.lowercase()) }
      "getPushSubscription" -> {
        val s = Onda.getPushSubscription()
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
    put("data", p.data)
  }
}
