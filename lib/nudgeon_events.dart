/// Recommended event names shared with the NudgeOn console.
/// Pass to NudgeOn.track after success. Constants do not emit events or identify
/// users; custom event names remain supported.
abstract final class NudgeOnEvents {
  static const String signUp = 'sign_up';
  static const String login = 'login';
  static const String purchaseCompleted = 'purchase_completed';
  static const String productViewed = 'product_viewed';
  static const String addToCart = 'add_to_cart';
  static const String checkoutStarted = 'checkout_started';
}
