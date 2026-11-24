import 'package:web/web.dart' as web;

Future<bool> openExternalUrlPlatform(Uri uri) async {
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  return web.window.open(uri.toString(), '_blank', 'noopener,noreferrer') !=
      null;
}
