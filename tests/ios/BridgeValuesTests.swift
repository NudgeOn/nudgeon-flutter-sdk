import XCTest
import NudgeOnSDK
@testable import BridgeValues

final class BridgeValuesTests: XCTestCase {
    func testScalarResultsAreJSONIncludingEscapes() throws {
        for input in ["granted", "device-id", "quotes \" and \\ and 한글"] {
            let json = try XCTUnwrap(NudgeOnFlutterValues.string(from: input))
            let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed]) as? String
            XCTAssertEqual(decoded, input)
        }
    }

    func testJSONNumbersZeroAndOneDoNotBecomeBooleans() {
        let args = NudgeOnFlutterValues.dict(fromString: #"{"zero":0,"one":1,"fraction":1.5,"yes":true,"no":false,"tags":["a"],"unset":null}"#)
        let values = NudgeOnFlutterValues.values(args)
        guard case .number(0) = values["zero"], case .number(1) = values["one"],
              case .number(1.5) = values["fraction"], case .bool(true) = values["yes"],
              case .bool(false) = values["no"], case .stringArray(["a"]) = values["tags"],
              case .null = values["unset"] else { return XCTFail("Bridge changed JSON types") }
    }

    func testNonDefaultConfigurationIsForwarded() throws {
        let cfg = try XCTUnwrap(NudgeOnFlutterValues.config(["sdkKey":"pk_test", "apiHost":"https://example.invalid", "appGroup":"group.test", "logLevel":"none", "flushInterval":37, "flushBatchSize":4, "autoTrackSessions":false, "autoRegisterPushToken":false]))
        XCTAssertEqual(cfg.appGroup, "group.test")
        XCTAssertEqual(cfg.logLevel, .none)
        XCTAssertEqual(cfg.flushInterval, 37)
        XCTAssertEqual(cfg.flushBatchSize, 4)
        XCTAssertFalse(cfg.autoTrackSessions)
        XCTAssertFalse(cfg.autoRegisterPushToken)
    }

    func testInvalidConfigurationIsRejected() {
        let base: [String: Any] = ["sdkKey":"pk_test", "apiHost":"https://example.invalid"]
        for changes: [String: Any] in [["sdkKey":""], ["apiHost":"file:///tmp/x"], ["flushInterval":0], ["flushBatchSize":1.5], ["logLevel":"unknown"]] {
            XCTAssertNil(NudgeOnFlutterValues.config(base.merging(changes) { _, new in new }))
        }
    }
}
