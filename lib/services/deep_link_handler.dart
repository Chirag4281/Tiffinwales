
// lib/services/deep_link_handler.dart

import 'dart:async';
import 'package:app_links/app_links.dart';

/// Handles deep links for payment returns.
///
/// Used by the Halo Payments hosted checkout flow to receive
/// the redirect back into the application.
///
/// Expected redirect format:
/// myapp://payment-result?status=success&payment_id=XXX&order_id=XXX
class DeepLinkHandler {
static DeepLinkHandler? _instance;

final AppLinks _appLinks = AppLinks();

StreamSubscription<Uri>? _linkSubscription;

final StreamController<PaymentDeepLinkResult> _resultController =
StreamController<PaymentDeepLinkResult>.broadcast();

bool _initialized = false;

static DeepLinkHandler get instance {
_instance ??= DeepLinkHandler._();
return _instance!;
}

DeepLinkHandler._();

/// Initialize deep-link handling.
///
/// Call this once when the application starts.
Future<void> initialize() async {
if (_initialized) {
return;
}

_initialized = true;

print('[DEEP_LINK] Initializing...');

// ---------------------------------------------------------
// Handle the link that launched the application.
// ---------------------------------------------------------
try {
final Uri? initialUri = await _appLinks.getInitialAppLink();

if (initialUri != null) {
print(
'[DEEP_LINK] Initial URI: ${initialUri.toString()}',
);

_handleDeepLink(initialUri);
}
} catch (e) {
print('[DEEP_LINK] Initial link error: $e');
}

// ---------------------------------------------------------
// Listen for links received while the application is open.
// ---------------------------------------------------------
try {
_linkSubscription = _appLinks.uriLinkStream.listen(
(Uri uri) {
print(
'[DEEP_LINK] Received URI: ${uri.toString()}',
);

_handleDeepLink(uri);
},
onError: (Object error) {
print('[DEEP_LINK] Stream error: $error');
},
);
} catch (e) {
print('[DEEP_LINK] Failed to initialize link stream: $e');
}
}

/// Parse and handle a deep link.
void _handleDeepLink(Uri uri) {
try {
print('[DEEP_LINK] --------------------------------');
print('[DEEP_LINK] URI: ${uri.toString()}');
print('[DEEP_LINK] Scheme: ${uri.scheme}');
print('[DEEP_LINK] Host: ${uri.host}');
print('[DEEP_LINK] Path: ${uri.path}');
print('[DEEP_LINK] Query: ${uri.queryParameters}');

// -------------------------------------------------------
// Only handle our application scheme.
// -------------------------------------------------------
if (uri.scheme.toLowerCase() != 'myapp') {
print(
'[DEEP_LINK] Ignoring unsupported scheme: ${uri.scheme}',
);
return;
}

// -------------------------------------------------------
// Only handle the payment-result route.
//
// Expected:
//
// myapp://payment-result?status=success
//
// Depending on URI parsing, payment-result can appear
// as the host rather than the path.
// -------------------------------------------------------
final String route = uri.host.isNotEmpty
? uri.host
    : uri.path.replaceFirst('/', '');

if (route != 'payment-result') {
print(
'[DEEP_LINK] Ignoring unsupported route: $route',
);
return;
}

// -------------------------------------------------------
// Read parameters.
// -------------------------------------------------------
final String status =
uri.queryParameters['status']?.toLowerCase() ?? 'unknown';

final String? paymentId =
uri.queryParameters['payment_id'] ??
uri.queryParameters['paymentId'];

final String? orderId =
uri.queryParameters['order_id'] ??
uri.queryParameters['orderId'];

print(
'[DEEP_LINK] Payment result received '
'status=$status, '
'paymentId=$paymentId, '
'orderId=$orderId',
);

// -------------------------------------------------------
// Emit payment result.
// -------------------------------------------------------
if (!_resultController.isClosed) {
_resultController.add(
PaymentDeepLinkResult(
status: status,
paymentId: paymentId,
orderId: orderId,
),
);
}
} catch (e) {
print('[DEEP_LINK] Parse error: $e');
}
}

/// Stream of payment results.
Stream<PaymentDeepLinkResult> get paymentResultStream =>
_resultController.stream;

/// Dispose resources.
Future<void> dispose() async {
await _linkSubscription?.cancel();

_linkSubscription = null;

if (!_resultController.isClosed) {
await _resultController.close();
}

_initialized = false;
}
}

/// Result received from the application deep link.
class PaymentDeepLinkResult {
final String status;
final String? paymentId;
final String? orderId;

const PaymentDeepLinkResult({
required this.status,
this.paymentId,
this.orderId,
});

bool get isSuccess => status == 'success';

bool get isCancelled => status == 'cancelled';

bool get isFailed => status == 'failed';

bool get isUnknown => status == 'unknown';

@override
String toString() {
return 'PaymentDeepLinkResult('
'status: $status, '
'paymentId: $paymentId, '
'orderId: $orderId'
')';
}
}

