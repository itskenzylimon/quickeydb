import 'package:flutter/foundation.dart';

/// Platform-specific guidance; never suggests replacing an existing data key.
String startupHelp({required bool isWeb, required TargetPlatform platform}) {
  const keyAdvice =
      'If an existing key is missing or rejected, restore the original key. Do not clear data or generate a replacement.';
  final platformAdvice = isWeb
      ? 'Use localhost or HTTPS, keep the same hostname and port, and run the SQLite worker setup if assets are missing.'
      : switch (platform) {
          TargetPlatform.macOS =>
            'Check Keychain Sharing entitlements and development signing in macos/Runner.xcworkspace. Complete Xcode setup and install CocoaPods before building.',
          TargetPlatform.iOS =>
            'Check iOS Keychain access, signing, CocoaPods and the iOS platform components installed in Xcode.',
          TargetPlatform.linux =>
            'Install libsecret/jsoncpp dependencies and make sure the desktop secret service/keyring is running and unlocked.',
          TargetPlatform.windows =>
            'Check the Windows secure-storage plugin and the Visual Studio C++ desktop/Windows SDK build prerequisites.',
          TargetPlatform.android =>
            'Check Android secure-storage setup and device logs. Restore the original key with its data; Android backup is disabled in this example.',
          TargetPlatform.fuchsia =>
            'This example has not been configured or verified for Fuchsia secure storage.',
        };
  return '$platformAdvice\n\n$keyAdvice';
}
