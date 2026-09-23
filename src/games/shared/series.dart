/// A fixed-length history of one number over time.
///
/// The ecology page charts three of these. A ring buffer keeps the cost of a
/// long-running tab flat: a simulation left open for an hour holds exactly as
/// much memory as one opened a second ago, and the chart never has to decide
/// what to throw away mid-draw.
class Series {
  final String label;
  final int capacity;
  final List<double> _values;
  int _start = 0;
  int _length = 0;

  Series(this.label, {this.capacity = 600}) : _values = List<double>.filled(capacity, 0);

  int get length => _length;
  bool get isEmpty => _length == 0;

  /// How many samples have ever been added, which is also the x coordinate of
  /// the most recent one. The chart uses it to label a scrolling axis.
  int get totalAdded => _totalAdded;
  int _totalAdded = 0;

  void add(double value) {
    if (_length < capacity) {
      _values[(_start + _length) % capacity] = value;
      _length++;
    } else {
      _values[_start] = value;
      _start = (_start + 1) % capacity;
    }
    _totalAdded++;
  }

  double operator [](int index) => _values[(_start + index) % capacity];

  double get last => _length == 0 ? 0 : this[_length - 1];

  double get max {
    var top = 0.0;
    for (var i = 0; i < _length; i++) {
      if (this[i] > top) top = this[i];
    }
    return top;
  }

  void clear() {
    _start = 0;
    _length = 0;
    _totalAdded = 0;
  }
}
