import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

void _showErrorDialog(String title, String message) => using((arena) {
  MessageBox(
    null,
    arena.pcwstr(message),
    arena.pcwstr(title),
    MB_ICONERROR | MB_OK,
  );
});

void showWebViewDialog() => _showErrorDialog(
  'WebView2 Error',
  'WebView2 is required to run this application. Please install it from https://go.microsoft.com/fwlink/?linkid=2135547',
);

void showRustLibMissingDialog() => _showErrorDialog(
  'Native Library Missing',
  'The required native library is missing. This can be caused by antivirus software removing the file. Please exclude the application from your antivirus and reinstall.',
);
