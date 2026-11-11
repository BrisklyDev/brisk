import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';

/// Callack function to set in setFilter.
typedef FilteredListFilter<E> = bool Function(E element);

/// Properties and methods extended to [List].
abstract class AbstractFilteredList<E> implements ListBase<E> {
  /// Pure unfiltered list.
  List<E> get originalList;

  /// Filtered list. Same as [originalList] if filter is null.
  List<E> get filteredList;

  /// If it is filtered, return the original list if it is not a filtered list.
  /// (list before range is applied)
  List<E> get filterOrOriginalList;

  /// Whether to set a filter.
  bool get hasFilter;

  /// Method to set the filter.
  void setFilter(FilteredListFilter<E> filter);

  /// [List.remove] method removes an element from the filtered scope.
  /// Use removeFromOriginal to remove elements from all list scopes.
  bool removeFromOriginal(Object element);

  /// [List.removeWhere] method removes an element from the filtered scope.
  /// Use removeWhereFromOriginal to remove elements from all list scopes.
  void removeWhereFromOriginal(bool Function(E element) test);

  /// [List.retainWhere] method removes an element from the filtered scope.
  /// Use retainWhereFromOriginal to remove elements from all list scopes.
  void retainWhereFromOriginal(bool Function(E element) test);

  /// [List.clear] method removes an element from the filtered scope.
  /// Use clearFromOriginal to remove elements from all list scopes.
  void clearFromOriginal();

  /// [List.removeLast] method removes an element from the filtered scope.
  /// Use removeLastFromOriginal to remove an element from all list scopes.
  E removeLastFromOriginal();

  /// Update filtering results.
  /// Called when the filter is not changed
  /// and the filtering result changes due to the change of the attribute value of the list.
  void update();
}

/// force the scope of the list
class FilteredListRange {
  /// Used as getRange(from, to)
  FilteredListRange(this._from, this._to);

  int _from = 0;

  /// The starting index of the range.
  int get from => _from;

  int _to = 0;

  /// The end index of the range.
  int get to => _to;

  /// Set the range of the list.
  /// If [from] and [to] are set on a page-by-page basis, pagination can be used.
  void setRange(int from, int to) {
    _from = from;
    _to = to;
  }
}

/// An extension class of List that applies a filter to a List and can access,
/// modify, or delete the list in that state.
class FilteredList<E> extends ListBase<E> implements AbstractFilteredList<E> {
  /// Pass the list to be set initially to initialList.
  /// If not passed, an empty list is created.
  ///
  /// ```dart
  /// FilteredList();
  /// FilteredList(initialList: [1, 2, 3]);
  /// ```
  FilteredList({
    List<E>? initialList,
  }) : _list = initialList ?? [];

  final List<E> _list;

  FilteredListFilter<E>? _filter;

  FilteredListRange? _range;

  int get _safetyFrom {
    if (_range == null || _range!.from < 0) {
      return 0;
    }

    if (_range!.from > _maxLength - 1) {
      return _maxLength;
    }

    return _range!.from;
  }

  int get _safetyTo {
    if (_range == null || _range!.to < 0) {
      return 0;
    }

    if (_range!.to > _maxLength) {
      return _maxLength;
    }

    return _range!.to;
  }

  int get _maxLength => hasFilter ? _filteredList.length : _list.length;

  List<E> get _effectiveList => hasFilter
      ? hasRange
          ? _filteredList.getRange(_safetyFrom, _safetyTo).toList()
          : _filteredList
      : hasRange
          ? _list.getRange(_safetyFrom, _safetyTo).toList()
          : _list;

  List<E> _filteredList = [];

  /// Returns all elements regardless of filtering or ranging.
  @override
  List<E> get originalList => [..._list];

  /// Returns the filtered elements.
  @override
  List<E> get filteredList => [..._filteredList];

  @override
  List<E> get filterOrOriginalList => hasFilter ? filteredList : originalList;

  @override
  bool get hasFilter => _filter != null;

  bool get hasRange => _range != null;

  /// Returns the length of the elements with filtering or ranging applied.
  @override
  int get length => _effectiveList.length;

  /// Returns the length of all elements, regardless of filtering or ranging.
  int get originalLength => _list.length;

  int get filterOrOriginalLength =>
      hasFilter ? _filteredList.length : _list.length;

  @override
  set length(int length) {
    _list.length = length;
  }

  /// Apply the filtering state to the list
  /// by implementing a [filter] callback that returns a bool.
  @override
  void setFilter(FilteredListFilter<E>? filter) {
    _filter = filter;

    _updateFilteredList();
  }

  /// Apply the range setting to the list by passing [FilteredListRange].
  void setFilterRange(FilteredListRange? range) {
    _range = range;
  }

  @override
  void add(E element) {
    _list.add(element);

    _updateFilteredList();
  }

  @override
  void addAll(Iterable<E> iterable) {
    _list.addAll(iterable);

    _updateFilteredList();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    _workOnOriginalList(() {
      super.sort(compare);
    });

    _updateFilteredList();
  }

  @override
  bool remove(Object? element) {
    if (_isNotInList(element, _effectiveList)) {
      return false;
    }

    return removeFromOriginal(element);
  }

  @override
  bool removeFromOriginal(Object? element) {
    bool result = false;

    _workOnOriginalList(() {
      result = super.remove(element);
    });

    _updateFilteredList();

    return result;
  }

  @override
  void removeWhere(bool Function(E element) test) {
    var list = _effectiveList;

    _workOnOriginalList(() {
      super.removeWhere((E element) {
        return _isInList(element, list) && test(element);
      });
    });

    _updateFilteredList();
  }

  @override
  void removeWhereFromOriginal(bool Function(E element) test) {
    _workOnOriginalList(() {
      super.removeWhere(test);
    });

    _updateFilteredList();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    var list = _effectiveList;

    _workOnOriginalList(() {
      super.retainWhere((E element) {
        var isInList = _isInList(element, list);
        return !isInList || (_isInList(element, list) && test(element));
      });
    });

    _updateFilteredList();
  }

  @override
  void retainWhereFromOriginal(bool Function(E element) test) {
    _workOnOriginalList(() {
      super.retainWhere(test);
    });

    _updateFilteredList();
  }

  @override
  void clear() {
    var list = _effectiveList;

    _workOnOriginalList(() {
      super.removeWhere((E element) {
        return _isInList(element, list);
      });
    });

    _updateFilteredList();
  }

  @override
  void clearFromOriginal() {
    length = 0;

    _updateFilteredList();
  }

  @override
  E removeLast() {
    var result = removeAt(_effectiveList.length - 1);

    _updateFilteredList();

    return result;
  }

  @override
  E removeLastFromOriginal() {
    late E result;

    _workOnOriginalList(() {
      result = super.removeLast();
    });

    _updateFilteredList();

    return result;
  }

  @override
  void shuffle([Random? random]) {
    _workOnOriginalList(() {
      super.shuffle(random);
    });

    _updateFilteredList();
  }

  @override
  void removeRange(int start, int end) {
    // todo : implement
    throw UnimplementedError('removeRange');
  }

  @override
  void fillRange(int start, int end, [E? fill]) {
    // todo : implement
    throw UnimplementedError('fillRange');
  }

  @override
  void replaceRange(int start, int end, Iterable<E> newContents) {
    // todo : implement
    throw UnimplementedError('replaceRange');
  }

  @override
  void insert(int index, E element) {
    var originalIndex = _toOriginalIndexForInsert(index);

    _workOnOriginalList(() {
      super.insert(originalIndex, element);
    });

    _updateFilteredList();
  }

  @override
  E removeAt(int index) {
    var originalIndex = _toOriginalIndex(index);

    late E result;

    _workOnOriginalList(() {
      result = super.removeAt(originalIndex);
    });

    _updateFilteredList();

    return result;
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    var originalIndex = _toOriginalIndexForInsert(index);

    _workOnOriginalList(() {
      super.insertAll(originalIndex, iterable);
    });

    _updateFilteredList();
  }

  @override
  E operator [](int index) {
    return _effectiveList[index];
  }

  @override
  void operator []=(int index, E value) {
    if (!hasFilter) {
      _list[index] = value;
      return;
    }

    _list[_toOriginalIndex(index)] = value;

    _updateFilteredList();
  }

  @override
  void update() {
    _updateFilteredList();
  }

  bool _compare(dynamic a, dynamic b) {
    if (a is String || a is int || a is double || a is bool) {
      return a == b;
    } else if (a is Set || a is Map || a is List || a is Iterable) {
      return const DeepCollectionEquality().equals(a, b);
    }

    return a == b;
  }

  void _workOnOriginalList(void Function() callback) {
    if (!hasFilter && !hasRange) {
      callback();
      return;
    }

    final storeFilter = _filter;

    final storeRange = _range;

    setFilter(null);

    setFilterRange(null);

    callback();

    setFilter(storeFilter);

    setFilterRange(storeRange);
  }

  bool _isInList(Object? element, List<E> list) {
    return list.firstWhereOrNull(
          (e) => e == element,
        ) !=
        null;
  }

  bool _isNotInList(Object? element, List<E> list) {
    return !_isInList(element, list);
  }

  int _toOriginalIndex(int index) {
    if (_effectiveList.isEmpty || (!hasFilter && !hasRange)) {
      return index;
    }

    final originalValue = _effectiveList[index];

    final valueIndexes = _list
        .asMap()
        .entries
        .map((e) => _compare(e.value, originalValue) ? e.key : -1)
        .where((element) => element != -1);

    final found = valueIndexes.length;

    if (found < 1) {
      throw Exception(
          'With the filter applied, the value cannot be found in the list by that index.');
    }

    if (found == 1) {
      return valueIndexes.first;
    }

    return valueIndexes.elementAt(index);
  }

  int _toOriginalIndexForInsert(int index) {
    var lastIndex = _effectiveList.length - 1;

    var greaterThanLast = index > lastIndex;

    var originalIndex = _toOriginalIndex(greaterThanLast ? lastIndex : index);

    return greaterThanLast ? ++originalIndex : originalIndex;
  }

  void _updateFilteredList() {
    _filteredList = _filter == null ? [] : _list.where(_filter!).toList();
  }
}
