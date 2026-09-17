import Flutter
import NudgeOnSDK
import UIKit

/// Flutter 브리지 (iOS) — 무상태. MethodChannel 호출을 NudgeOnSDK 코어로 위임하고,
/// EventChannel로 pushOpened/received를 스트리밍한다 (PRD-01A 3.4·4장).
public class NudgeOnFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var openedToken: UUID?
  private var receivedToken: UUID?
  private var events: Set<String> = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = NudgeOnFlutterPlugin()
    let methods = FlutterMethodChannel(name: "io.nudgeon/methods", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: "io.nudgeon/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  // MARK: EventChannel — 구독 시 코어 EventBus가 버퍼(최대 20건) 재생 (이벤트별 네이티브 버퍼 재생)
  public func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    clearSubscriptions()
    sink = events
    attachListeners()
    return nil
  }

  public func onCancel(withArguments _: Any?) -> FlutterError? {
    clearSubscriptions()
    events.removeAll()
    sink = nil
    return nil
  }

  private func clearSubscriptions() {
    if let t = openedToken { NudgeOn.off(t) }
    if let t = receivedToken { NudgeOn.off(t) }
    openedToken = nil; receivedToken = nil
  }

  private func attachListeners() {
    guard sink != nil else { return }
    if events.contains("pushOpened"), openedToken == nil { openedToken = NudgeOn.onPushOpened { [weak self] p in self?.forward("pushOpened", p) } }
    if events.contains("pushReceived"), receivedToken == nil { receivedToken = NudgeOn.onPushReceived { [weak self] p in self?.forward("pushReceived", p) } }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    _ = onCancel(withArguments: nil)
  }

  private func forward(_ event: String, _ p: PushPayload) {
    sink?(["event": event, "payload": Self.payloadMap(p)])
  }

  // MARK: MethodChannel — 단일 dispatch
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "subscribeEvent", "unsubscribeEvent":
      guard let event = args["event"] as? String, ["pushOpened", "pushReceived"].contains(event) else { result(FlutterError(code: "E_ARGS", message: "event 인자 오류", details: nil)); return }
      if call.method == "subscribeEvent" { events.insert(event); attachListeners() }
      else {
        events.remove(event)
        if event == "pushOpened", let token = openedToken { NudgeOn.off(token); openedToken = nil }
        if event == "pushReceived", let token = receivedToken { NudgeOn.off(token); receivedToken = nil }
      }
      result(nil)
    case "initialize":
      guard let config = NudgeOnFlutterValues.config(args) else { result(FlutterError(code: "E_ARGS", message: "initialize 인자 오류", details: nil)); return }
      NudgeOn.initialize(config: config); attachListeners(); result(nil)
    case "identify": NudgeOn.identify(externalId: args["externalId"] as? String ?? ""); result(nil)
    case "reset": NudgeOn.reset(); result(nil)
    case "setUserAttributes":
      NudgeOn.setUserAttributes(NudgeOnFlutterValues.values(args["attrs"] as? [String: Any] ?? [:])); result(nil)
    case "track":
      NudgeOn.track(args["name"] as? String ?? "", properties: args["properties"] as? [String: Any]); result(nil)
    case "flush": NudgeOn.flush(); result(nil)
    case "setPushSubscription": NudgeOn.setPushSubscription(args["optedIn"] as? Bool ?? true); result(nil)
    case "setLogLevel":
      guard let level = NudgeOnFlutterValues.logLevel(args["level"] as? String ?? "") else { result(FlutterError(code: "E_ARGS", message: "logLevel 인자 오류", details: nil)); return }
      NudgeOn.setLogLevel(level); result(nil)
    case "getDeviceId": result(NudgeOn.getDeviceId())
    case "getAnonId": result(NudgeOn.getAnonId())
    case "getInitialPushPayload":
      result(NudgeOn.getInitialPushPayload().map { Self.payloadMap($0) })
    case "registerForPush":
      Task { let r = await NudgeOn.registerForPush(); result(r.rawValue) }
    case "getPushSubscription":
      Task {
        let s = await NudgeOn.getPushSubscription()
        result(["serviceOptIn": s.serviceOptIn, "osPermission": s.osPermission, "tokenRegistered": s.tokenRegistered])
      }
    default: result(FlutterMethodNotImplemented)
    }
  }

  private static func payloadMap(_ p: PushPayload) -> [String: Any] {
    var d: [String: Any] = ["messageId": p.messageId, "title": p.title, "body": p.body, "data": p.data]
    if let c = p.campaignId { d["campaignId"] = c }
    if let j = p.journeyId { d["journeyId"] = j }
    if let l = p.deepLink { d["deepLink"] = l }
    if let i = p.imageUrl { d["imageUrl"] = i }
    d["silent"] = p.silent
    return d
  }

}
