/// Compares the installed app against a store listing without trusting
/// `new_version_plus`'s `canUpdate`, which treats `"Version 11"` as `11 > 1.0.11`.
abstract final class AppUpdate {
  /// Returns true only when [storeVersion] is strictly newer than the
  /// installed [localVersion] / [buildNumber].
  ///
  /// A single-number store label (`Version 11`) is compared to [buildNumber],
  /// which is how App Store Connect is currently set. Dotted strings are
  /// compared as padded semver. Parse failures never prompt an update.
  static bool isStoreNewer({
    required String localVersion,
    required String buildNumber,
    required String storeVersion,
  }) {
    final store = _parts(storeVersion);
    final local = _parts(localVersion);
    if (store.isEmpty || local.isEmpty) return false;

    if (store.length == 1) {
      final build = int.tryParse(buildNumber) ?? local.last;
      return store.first > build;
    }

    final n = store.length > local.length ? store.length : local.length;
    for (var i = 0; i < n; i++) {
      final s = i < store.length ? store[i] : 0;
      final l = i < local.length ? local[i] : 0;
      if (s > l) return true;
      if (l > s) return false;
    }
    return false;
  }

  static List<int> _parts(String version) {
    return [
      for (final match in RegExp(r'\d+').allMatches(version))
        int.parse(match.group(0)!),
    ];
  }
}
