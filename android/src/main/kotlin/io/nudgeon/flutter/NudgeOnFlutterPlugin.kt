package io.nudgeon.flutter

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
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
class NudgeOnFlutterPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler,
  ActivityAware, PluginRegistry.RequestPermissionsResultListener {
  private lateinit var methods: MethodChannel
  private lateinit var events: EventChannel
  private lateinit var appContext: Context
  private var sink: EventChannel.EventSink? = null
  private var openedToken: UUID? = null
  private var receivedToken: UUID? = null
  private var activityBinding: ActivityPluginBinding? = null
  private val subscribedEvents = mutableSetOf<String>()

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    methods = MethodChannel(binding.binaryMessenger, "io.nudgeon/methods").apply { setMethodCallHandler(this@NudgeOnFlutterPlugin) }
    events = EventChannel(binding.binaryMessenger, "io.nudgeon/events").apply { setStreamHandler(this@NudgeOnFlutterPlugin) }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    onCancel(null)
    onDetachedFromActivity()
    methods.setMethodCallHandler(null)
    events.setStreamHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    binding.addRequestPermissionsResultListener(this)
  }
  override fun onDetachedFromActivity() {
    activityBinding?.removeRequestPermissionsResultListener(this)
    activityBinding = null
  }
  override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean =
    NudgeOn.onRequestPermissionsResult(requestCode, permissions, grantResults)

  // EventChannel — 구독 시 코어 EventBus가 버퍼(최대 20건) 재생 (이벤트별 네이티브 버퍼 재생)
  override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
    clearSubscriptions()
    this.sink = sink
    attachListeners()
  }

  override fun onCancel(arguments: Any?) {
    clearSubscriptions()
    subscribedEvents.clear()
    sink = null
  }

  private fun clearSubscriptions() {
    openedToken?.let { NudgeOn.off(it) }
    receivedToken?.let { NudgeOn.off(it) }
    openedToken = null; receivedToken = null
  }

  private fun attachListeners() {
    if (sink == null) return
    if ("pushOpened" in subscribedEvents && openedToken == null) openedToken = NudgeOn.onPushOpened { forward("pushOpened", it) }
    if ("pushReceived" in subscribedEvents && receivedToken == null) receivedToken = NudgeOn.onPushReceived { forward("pushReceived", it) }
  }

  private fun forward(event: String, p: PushPayload) {
    sink?.success(mapOf("event" to event, "payload" to payloadMap(p)))
  }

  override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "subscribeEvent", "unsubscribeEvent" -> {
        val event = call.argument<String>("event")
        if (event !in listOf("pushOpened", "pushReceived")) { result.error("E_ARGS", "Invalid event", null); return }
        if (call.method == "subscribeEvent") { subscribedEvents.add(event!!); attachListeners() }
        else {
          subscribedEvents.remove(event)
          if (event == "pushOpened") { openedToken?.let { NudgeOn.off(it) }; openedToken = null }
          if (event == "pushReceived") { receivedToken?.let { NudgeOn.off(it) }; receivedToken = null }
        }
        result.success(null)
      }
      "initialize" -> {
        if (call.hasArgument("logLevel")) {
          result.error("E_UNSUPPORTED", "Android core 0.2.2 does not support logLevel", null); return
        }
        val key = call.argument<String>("sdkKey") ?: ""
        val host = call.argument<String>("apiHost") ?: ""
        val uri = runCatching { java.net.URI(host) }.getOrNull()
        val interval = call.argument<Number>("flushInterval")?.toDouble() ?: 10.0
        val size = call.argument<Number>("flushBatchSize")?.toDouble() ?: 10.0
        if (key.isEmpty() || uri?.host == null || uri.scheme !in listOf("http", "https") ||
          !interval.isFinite() || interval < 1 || interval > Int.MAX_VALUE || interval % 1.0 != 0.0 ||
          !size.isFinite() || size < 1 || size > Int.MAX_VALUE || size % 1.0 != 0.0) {
          result.error("E_ARGS", "Invalid initialize configuration", null); return
        }
        NudgeOn.initialize(
          appContext,
          NudgeOnConfig(sdkKey = key, apiHost = host,
            flushIntervalSeconds = interval.toLong(), flushBatchSize = size.toInt(),
            autoTrackSessions = call.argument("autoTrackSessions") ?: true,
            autoRegisterPushToken = call.argument("autoRegisterPushToken") ?: true),
        )
        attachListeners()
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
      "setLogLevel" -> result.error("E_UNSUPPORTED", "Android core 0.2.2 does not support logLevel", null)
      "getDeviceId" -> result.success(NudgeOn.getDeviceId())
      "getAnonId" -> result.success(NudgeOn.getAnonId())
      "getInitialPushPayload" -> result.success(NudgeOn.getInitialPushPayload()?.let { payloadMap(it) })
      "registerForPush" -> NudgeOn.registerForPush(activityBinding?.activity) { r -> result.success(r.name.lowercase()) }
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
