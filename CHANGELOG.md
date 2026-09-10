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
