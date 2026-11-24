import 'external_url_opener_stub.dart'
    if (dart.library.js_interop) 'external_url_opener_web.dart'
    if (dart.library.io) 'external_url_opener_native.dart'
    as impl;

Future<bool> Function(Uri uri)? externalUrlOpenerOverrideForTest;

Future<bool> openExternalUrl(Uri uri) {
  final override = externalUrlOpenerOverrideForTest;
  if (override != null) return override(uri);
  return impl.openExternalUrlPlatform(uri);
}
