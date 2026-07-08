/// Build metadata baked in via --dart-define at build time (see
/// tool/build_with_version.sh). A plain `flutter run` without that script
/// leaves these at their defaults, so a dev build is still visually
/// distinguishable from a real versioned build in Settings.
class BuildInfo {
  BuildInfo._();

  static const String gitCommit =
      String.fromEnvironment('GIT_COMMIT', defaultValue: 'dev');
  static const String buildTime =
      String.fromEnvironment('BUILD_TIME', defaultValue: '');

  static bool get isVersioned => gitCommit != 'dev' && gitCommit.isNotEmpty;

  static String get label {
    if (!isVersioned) return 'dev build';
    if (buildTime.isEmpty) return gitCommit;
    return '$gitCommit · $buildTime';
  }
}
