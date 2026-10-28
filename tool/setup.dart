// One-time setup for Android, iOS and web. Run from the project root:
//
//   dart run tool/setup.dart
//
// It creates the platform folders, applies the settings Firebase needs on
// each platform, and generates the app icons. Safe to run more than once.
import 'dart:io';

void main() async {
  _step('Creating android/, ios/ and web/ (existing files are kept)');
  await _run('flutter', [
    'create',
    '.',
    '--project-name',
    'perps_league',
    '--org',
    'com.perpsleague',
    '--platforms',
    'android,ios,web',
  ]);

  // The template's sample test references a MyApp class this app doesn't have.
  final sample = File('test/widget_test.dart');
  if (sample.existsSync() && sample.readAsStringSync().contains('MyApp')) {
    sample.deleteSync();
    _ok('Removed the template test/widget_test.dart');
  }

  _patchAndroid();
  _patchIos();

  _step('Fetching packages');
  await _run('flutter', ['pub', 'get']);

  _step('Generating app icons for Android, iOS and web');
  await _run('dart', ['run', 'flutter_launcher_icons']);

  stdout.writeln('''

Done. Next:
  1. dart pub global activate flutterfire_cli
  2. flutterfire configure --platforms=android,ios,web
  3. flutter run -d chrome     (web)
     flutter run               (connected Android or iOS device)
''');
}

/// Release builds need INTERNET (the template only adds it to debug), and
/// firebase_auth needs minSdk 23.
void _patchAndroid() {
  _step('Configuring Android');
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (manifest.existsSync()) {
    var xml = manifest.readAsStringSync();
    if (!xml.contains('android.permission.INTERNET')) {
      xml = xml.replaceFirstMapped(
        RegExp(r'<manifest[^>]*>'),
        (m) => '${m[0]}\n    <uses-permission android:name="android.permission.INTERNET"/>',
      );
      manifest.writeAsStringSync(xml);
      _ok('Added INTERNET permission for release builds');
    }
  }

  for (final path in ['android/app/build.gradle.kts', 'android/app/build.gradle']) {
    final f = File(path);
    if (!f.existsSync()) continue;
    var src = f.readAsStringSync();
    final before = src;
    src = src.replaceAll(RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion'), 'minSdk = 23');
    src = src.replaceAll(RegExp(r'minSdkVersion\s+flutter\.minSdkVersion'), 'minSdkVersion 23');
    src = src.replaceAllMapped(RegExp(r'(minSdk\s*=\s*|minSdkVersion\s+)(\d+)'), (m) {
      final v = int.parse(m[2]!);
      return v < 23 ? '${m[1]}23' : m[0]!;
    });
    if (src != before) {
      f.writeAsStringSync(src);
      _ok('Set Android minSdk to 23 in $path');
    }
  }
}

/// Firebase's iOS SDK needs iOS 13 or later.
void _patchIos() {
  _step('Configuring iOS');
  final podfile = File('ios/Podfile');
  if (!podfile.existsSync()) {
    _ok('No Podfile yet; it is created on the first iOS build. Set "platform :ios, \'13.0\'" there.');
    return;
  }
  var src = podfile.readAsStringSync();
  final before = src;
  src = src.replaceFirst(RegExp(r"#\s*platform :ios, '[\d.]+'"), "platform :ios, '13.0'");
  src = src.replaceAllMapped(RegExp(r"platform :ios, '(\d+)(\.\d+)?'"), (m) {
    return int.parse(m[1]!) < 13 ? "platform :ios, '13.0'" : m[0]!;
  });
  if (src != before) {
    podfile.writeAsStringSync(src);
    _ok("Set iOS deployment target to 13.0 in ios/Podfile");
  }
}

Future<void> _run(String cmd, List<String> args) async {
  final p = await Process.start(cmd, args, runInShell: true, mode: ProcessStartMode.inheritStdio);
  final code = await p.exitCode;
  if (code != 0) {
    stderr.writeln('\n✗ "$cmd ${args.join(' ')}" failed with exit code $code');
    exit(code);
  }
}

void _step(String s) => stdout.writeln('\n▸ $s');
void _ok(String s) => stdout.writeln('  ✓ $s');
