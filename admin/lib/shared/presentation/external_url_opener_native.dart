import 'dart:io';

Future<bool> openExternalUrlPlatform(Uri uri) async {
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  try {
    if (Platform.isLinux) {
      await Process.start('xdg-open', [
        uri.toString(),
      ], mode: ProcessStartMode.detached);
      return true;
    }
    if (Platform.isMacOS) {
      await Process.start('open', [
        uri.toString(),
      ], mode: ProcessStartMode.detached);
      return true;
    }
    if (Platform.isWindows) {
      await Process.start('cmd', [
        '/c',
        'start',
        '',
        uri.toString(),
      ], mode: ProcessStartMode.detached);
      return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}
