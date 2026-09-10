import Flutter
import NudgeOnSDK
import UIKit

/// Flutter 브리지 (iOS) — 무상태. MethodChannel 호출을 NudgeOnSDK 코어로 위임하고,
/// EventChannel로 pushOpened/received를 스트리밍한다 (PRD-01A 3.4·4장).
public class NudgeOnFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var openedToken: UUID?
  private var receivedToken: UUID?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = NudgeOnFlutterPlugin()
    let methods = FlutterMethodChannel(name: "io.nudgeon/methods", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: "io.nudgeon/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  // MARK: EventChannel — 구독 시 코어 EventBus가 버퍼(최대 20건) 재생 (콜드 스타트 유실 0)
  public func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    openedToken = NudgeOn.onPushOpened { [weak self] p in self?.forward("pushOpened", p) }
    receivedToken = NudgeOn.onPushReceived { [weak self] p in self?.forward("pushReceived", p) }
    return nil
  }

  public func onCancel(withArguments _: Any?) -> FlutterError? {
    if let t = openedToken { NudgeOn.off(t) }
    if let t = receivedToken { NudgeOn.off(t) }
    sink = nil
    return nil
  }

  private func forward(_ event: String, _ p: PushPayload) {
    sink?(["event": event, "payload": Self.payloadMap(p)])
  }

  // MARK: MethodChannel — 단일 dispatch
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "initialize":
      guard let key = args["sdkKey"] as? String, let host = args["apiHost"] as? String,
            let url = URL(string: host) else { result(FlutterError(code: "E_ARGS", message: "initialize 인자 오류", details: nil)); return }
      NudgeOn.initialize(config: NudgeOnConfig(sdkKey: key, apiHost: url)); result(nil)
    case "identify": NudgeOn.identify(externalId: args["externalId"] as? String ?? ""); result(nil)
    case "reset": NudgeOn.reset(); result(nil)
    case "setUserAttributes":
      NudgeOn.setUserAttributes(Self.values(args["attrs"] as? [String: Any] ?? [:])); result(nil)
    case "track":
      NudgeOn.track(args["name"] as? String ?? "", properties: args["properties"] as? [String: Any]); result(nil)
    case "flush": NudgeOn.flush(); result(nil)
    case "setPushSubscription": NudgeOn.setPushSubscription(args["optedIn"] as? Bool ?? true); result(nil)
    case "setLogLevel": result(nil)
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

  private static func values(_ raw: [String: Any]) -> [String: NudgeOnValue] {
    raw.mapValues { v in
      switch v {
      case let s as String: return .string(s)
      case let b as Bool: return .bool(b)
      case let n as NSNumber: return .number(n.doubleValue)
      case let a as [String]: return .stringArray(a)
      default: return .null
      }
    }
  }
}
