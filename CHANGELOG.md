# Changelog

## Unreleased

- Use Android core 0.2.8 so explicit null attribute values reach the server as unset operations.

- Add `NudgeOnAttributes` profile keys for names, contact details, birthday, gender, home city, country, language, time zone, and signup date. Use the existing `setUserAttributes` API after `identify`; custom keys and null/unset remain supported.

- Add public `NudgeOnEvents` constants for sign-up, login, purchase, product views, cart additions, and checkout starts, matching the console catalog.
- Document recommended properties and preserve custom event names and the existing track transport.

## 0.1.3 — publication candidate

- Pin public native cores to 0.2.2 and align podspec/plugin versions.
- Share a native event stream and subscribe to event types only when their Dart listeners exist, retaining other event types in the native core buffer.
- Reattach pre-initialization listeners and clean up native subscriptions on cancellation/engine detach.
- Forward initialization options and iOS App Group/log level; preserve numeric attributes 0/1.
- Use Flutter's attached Activity and permission-result callback on Android. Unavailable Android log-level configuration returns `E_UNSUPPORTED`.
- Add native Swift contract tests and fresh consumer build validation. No physical-device push certification is included.

## 0.1.2

- Expose `imageUrl` and `silent` on `PushPayload`, mirroring the native SDKs
  (push payload contract R-01, 2026-09-10).
- Android: depend on the published core coordinate `io.nudgeon:nudgeon-sdk:0.1.2`
  (`nudgeon-android` never existed on Maven Central).

## 0.1.0

- Add the initial NudgeOn Flutter bridge for identity, tracking, push permission,
  push received/opened events, token registration, and local identity reset.
- Keep a single shared EventChannel stream so concurrent subscriptions do not
  replace or cancel one another.
