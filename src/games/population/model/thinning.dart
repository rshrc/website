/// Drops every other item of [samples], keeping the first. Long-running
/// histories halve their detail this way whenever they grow too long, so
/// they always span the whole run in bounded memory.
void keepEveryOther<T>(List<T> samples) {
  final kept = [for (var i = 0; i < samples.length; i += 2) samples[i]];
  samples
    ..clear()
    ..addAll(kept);
}
