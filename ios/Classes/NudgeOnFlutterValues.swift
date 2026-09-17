import Foundation
import CoreFoundation
import NudgeOnSDK

/// 브리지 직렬화 헬퍼 (PRD-01A 4장 타입 규칙).
enum NudgeOnFlutterValues {
  static func dict(fromString s: String) -> [String: Any] {
    guard let data = s.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
    return obj
  }
  static func string(from obj: Any) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.fragmentsAllowed]) else { return nil }
    return String(data: data, encoding: .utf8)
  }
  static func dict(_ p: PushPayload) -> [String: Any] {
    var d: [String: Any] = ["messageId": p.messageId, "title": p.title, "body": p.body, "data": p.data]
    if let c = p.campaignId { d["campaignId"] = c }
    if let j = p.journeyId { d["journeyId"] = j }
    if let l = p.deepLink { d["deepLink"] = l }
    if let i = p.imageUrl { d["imageUrl"] = i }
    d["silent"] = p.silent
    return d
  }
  static func values(_ raw: [String: Any]) -> [String: NudgeOnValue] {
    raw.mapValues { v in
      switch v {
      case let s as String: return .string(s)
      case let n as NSNumber:
        return CFGetTypeID(n) == CFBooleanGetTypeID() ? .bool(n.boolValue) : .number(n.doubleValue)
      case let a as [String]: return .stringArray(a)
      default: return .null
      }
    }
  }

  static func config(_ args: [String: Any]) -> NudgeOnConfig? {
    guard let key = args["sdkKey"] as? String, !key.isEmpty,
          let host = args["apiHost"] as? String, let url = URL(string: host),
          ["https", "http"].contains(url.scheme), url.host != nil else { return nil }
    let interval = (args["flushInterval"] as? NSNumber)?.doubleValue ?? 10
    let size = (args["flushBatchSize"] as? NSNumber)?.doubleValue ?? 10
    guard interval.isFinite, interval >= 1, interval.rounded() == interval,
          size.isFinite, size >= 1, size <= Double(Int32.max), size.rounded() == size else { return nil }
    guard let level = logLevel(args["logLevel"] as? String ?? "warn") else { return nil }
    return NudgeOnConfig(sdkKey: key, apiHost: url, appGroup: args["appGroup"] as? String,
                        logLevel: level, flushInterval: interval, flushBatchSize: Int(size),
                        autoTrackSessions: args["autoTrackSessions"] as? Bool ?? true,
                        autoRegisterPushToken: args["autoRegisterPushToken"] as? Bool ?? true)
  }

  static func logLevel(_ name: String) -> NudgeOnConfig.LogLevel? {
    switch name {
    case "none": return .some(.none)
    case "error": return .error
    case "warn": return .warn
    case "info": return .info
    case "debug": return .debug
    default: return nil
    }
  }
}
