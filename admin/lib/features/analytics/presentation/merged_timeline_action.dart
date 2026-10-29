/// Represents a consolidated sequence of consecutive identical actions in a timeline.
class MergedTimelineAction<T> {
  const MergedTimelineAction({
    required this.sample,
    required this.count,
    required this.firstAt,
    required this.lastAt,
    required this.key,
  });

  final T sample;
  final int count;
  final DateTime firstAt;
  final DateTime lastAt;
  final String key;
}

/// Merges consecutive identical actions in [items].
/// [keyOf] returns a string key identifying whether two actions are identical.
/// [timeOf] retrieves the timestamp of the action.
List<MergedTimelineAction<T>> mergeConsecutiveActions<T>({
  required List<T> items,
  required String Function(T item) keyOf,
  required DateTime Function(T item) timeOf,
}) {
  if (items.isEmpty) return const [];

  final result = <MergedTimelineAction<T>>[];
  T currentSample = items.first;
  String currentKey = keyOf(currentSample);
  DateTime firstTime = timeOf(currentSample);
  DateTime lastTime = firstTime;
  int count = 1;

  for (var i = 1; i < items.length; i++) {
    final item = items[i];
    final key = keyOf(item);
    final time = timeOf(item);
    if (key == currentKey) {
      count++;
      // Since timeline is typically sorted descending (most recent first) or ascending,
      // keep track of earliest and latest.
      if (time.isBefore(firstTime)) {
        firstTime = time;
      }
      if (time.isAfter(lastTime)) {
        lastTime = time;
      }
    } else {
      result.add(
        MergedTimelineAction<T>(
          sample: currentSample,
          count: count,
          firstAt: firstTime,
          lastAt: lastTime,
          key: currentKey,
        ),
      );
      currentSample = item;
      currentKey = key;
      firstTime = time;
      lastTime = time;
      count = 1;
    }
  }

  result.add(
    MergedTimelineAction<T>(
      sample: currentSample,
      count: count,
      firstAt: firstTime,
      lastAt: lastTime,
      key: currentKey,
    ),
  );

  return result;
}
