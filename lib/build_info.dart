class AppBuildInfo {
  const AppBuildInfo._();

  static const version = String.fromEnvironment(
    'AKATOR_VERSION',
    defaultValue: '1.0.0-dev',
  );
  static const buildNumber = String.fromEnvironment(
    'AKATOR_BUILD_NUMBER',
    defaultValue: 'local',
  );
  static const revision = String.fromEnvironment(
    'AKATOR_GIT_SHA',
    defaultValue: 'working-tree',
  );
  static const releaseTag = String.fromEnvironment(
    'AKATOR_RELEASE_TAG',
    defaultValue: 'unreleased',
  );

  static String get versionLabel => '$version ($buildNumber)';

  static String get revisionLabel {
    if (revision.length <= 12) {
      return revision;
    }
    return revision.substring(0, 12);
  }
}
