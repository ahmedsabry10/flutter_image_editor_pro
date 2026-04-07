/// Generic undo/redo history manager.
/// [T] is the state snapshot type.
class HistoryManager<T> {
  final int maxSteps;
  final List<T> _history = [];
  int _cursor = -1;

  HistoryManager({this.maxSteps = 20});

  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < _history.length - 1;
  T? get current => _cursor >= 0 ? _history[_cursor] : null;

  /// Push a new state. Clears any redo history ahead of cursor.
  void push(T state) {
    // Remove redo states
    if (_cursor < _history.length - 1) {
      _history.removeRange(_cursor + 1, _history.length);
    }
    _history.add(state);
    if (_history.length > maxSteps) {
      _history.removeAt(0);
    }
    _cursor = _history.length - 1;
  }

  /// Undo — returns previous state, or null if at start.
  T? undo() {
    if (!canUndo) return null;
    _cursor--;
    return _history[_cursor];
  }

  /// Redo — returns next state, or null if at end.
  T? redo() {
    if (!canRedo) return null;
    _cursor++;
    return _history[_cursor];
  }

  /// Clear all history.
  void clear() {
    _history.clear();
    _cursor = -1;
  }
}
