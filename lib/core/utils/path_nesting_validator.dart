/// Utility to check whether two directory paths are nested within each other
/// (i.e. one is a parent or child of the other).
class PathNestingValidator {
  const PathNestingValidator._();

  /// Normalizes a directory path for consistent comparison:
  /// - Replaces backslashes with forward slashes
  /// - Strips redundant trailing slashes (except root '/')
  /// - Case-insensitive on Windows/Android paths
  static String normalize(String path) {
    var p = path.trim().replaceAll(r'\', '/');
    while (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  /// Checks if [pathA] and [pathB] are nested (one contains the other, or identical).
  static bool areNested(String pathA, String pathB) {
    final normA = normalize(pathA);
    final normB = normalize(pathB);
    if (normA.isEmpty || normB.isEmpty) return false;

    final lowerA = normA.toLowerCase();
    final lowerB = normB.toLowerCase();
    if (lowerA == lowerB) return true;

    final prefixA = lowerA.endsWith('/') ? lowerA : '$lowerA/';
    final prefixB = lowerB.endsWith('/') ? lowerB : '$lowerB/';

    return lowerB.startsWith(prefixA) || lowerA.startsWith(prefixB);
  }

  /// Finds the first existing path in [existingPaths] that conflicts with [candidatePath].
  /// Returns the conflicting path, or `null` if none conflicts.
  static String? findConflict(String candidatePath, Iterable<String> existingPaths) {
    final normCandidate = normalize(candidatePath);
    if (normCandidate.isEmpty) return null;

    for (final existing in existingPaths) {
      if (areNested(normCandidate, existing)) {
        return existing;
      }
    }
    return null;
  }
}
