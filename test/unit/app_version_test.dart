import 'package:flutter_test/flutter_test.dart';
import 'package:delitopia_v2/src/core/models/app_version_info.dart';

void main() {
  group('AppVersionInfo Version Comparison Tests', () {
    test('compares lower minor and patch versions accurately', () {
      expect(AppVersionInfo.compareVersions('2.1.7', '2.1.8'), lessThan(0));
      expect(AppVersionInfo.compareVersions('2.0.9', '2.1.0'), lessThan(0));
      expect(AppVersionInfo.compareVersions('1.9.9', '2.0.0'), lessThan(0));
    });

    test('compares equal versions accurately', () {
      expect(AppVersionInfo.compareVersions('2.1.8', '2.1.8'), equals(0));
      expect(AppVersionInfo.compareVersions('2.1.8+31', '2.1.8'), equals(0));
    });

    test('compares higher versions accurately', () {
      expect(AppVersionInfo.compareVersions('2.1.9', '2.1.8'), greaterThan(0));
      expect(AppVersionInfo.compareVersions('3.0.0', '2.1.8'), greaterThan(0));
    });

    test('detects outdated when version is lower', () {
      final info = AppVersionInfo(
        latestVersion: '2.1.8',
        latestBuildNumber: 31,
        minVersion: '2.1.0',
        minBuildNumber: 25,
        forceUpdate: false,
        title: 'Pembaruan Tersedia',
        message: 'Versi terbaru tersedia.',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.delitopia.softindo',
      );

      expect(info.isOutdated(currentVersion: '2.1.7', currentBuild: 30), isTrue);
      expect(info.isOutdated(currentVersion: '2.1.8', currentBuild: 31), isFalse);
    });

    test('detects outdated when version is equal but build number is lower', () {
      final info = AppVersionInfo(
        latestVersion: '2.1.8',
        latestBuildNumber: 31,
        minVersion: '2.1.0',
        minBuildNumber: 25,
        forceUpdate: false,
        title: 'Pembaruan Tersedia',
        message: 'Versi terbaru tersedia.',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.delitopia.softindo',
      );

      expect(info.isOutdated(currentVersion: '2.1.8', currentBuild: 30), isTrue);
      expect(info.isOutdated(currentVersion: '2.1.8', currentBuild: 31), isFalse);
    });

    test('evaluates mandatory force update correctly', () {
      final infoForce = AppVersionInfo(
        latestVersion: '2.1.8',
        latestBuildNumber: 31,
        minVersion: '2.1.8',
        minBuildNumber: 31,
        forceUpdate: true,
        title: 'Pembaruan Wajib',
        message: 'Silakan perbarui aplikasi.',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.delitopia.softindo',
      );

      // Outdated user must update
      expect(infoForce.isMandatoryUpdate(currentVersion: '2.1.7', currentBuild: 30), isTrue);

      // Up-to-date user is not forced
      expect(infoForce.isMandatoryUpdate(currentVersion: '2.1.8', currentBuild: 31), isFalse);
    });

    test('evaluates minVersion threshold for force update', () {
      final infoOptional = AppVersionInfo(
        latestVersion: '2.1.8',
        latestBuildNumber: 31,
        minVersion: '2.1.5',
        minBuildNumber: 28,
        forceUpdate: false, // overall flag is false
        title: 'Pembaruan Tersedia',
        message: 'Silakan perbarui aplikasi.',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.delitopia.softindo',
      );

      // Version below minVersion (2.1.4 < 2.1.5) must force update
      expect(infoOptional.isMandatoryUpdate(currentVersion: '2.1.4', currentBuild: 27), isTrue);

      // Version between minVersion and latestVersion (2.1.6 >= 2.1.5) is outdated, but optional
      expect(infoOptional.isOutdated(currentVersion: '2.1.6', currentBuild: 29), isTrue);
      expect(infoOptional.isMandatoryUpdate(currentVersion: '2.1.6', currentBuild: 29), isFalse);
    });
  });
}
