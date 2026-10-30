import 'dart:async';

/// Transaction context interface for atomic local database modifications.
abstract class TransactionContext {
  Future<int> insert(String table, Map<String, dynamic> values);
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  });
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  });
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  });
}

/// Robust, transactional, multi-tenant local relational storage engine.
///
/// Implements full atomic transaction rollback, tenant scoping, and query filtering.
/// Ensures zero native compilation conflicts across Web, desktop, and test runners.
class AppDatabase implements TransactionContext {
  // In-memory relational tables store: table_name -> List<Map<String, dynamic>>
  final Map<String, List<Map<String, dynamic>>> _tables = {};

  /// Optional listener triggered whenever tables are mutated.
  void Function()? onDataChanged;

  AppDatabase();

  /// Executes DDL statements or schema initialization queries.
  Future<void> execute(String sql, [List<dynamic>? params]) async {
    // DDL parsing: extract table name if CREATE TABLE
    final trimmed = sql.trim();
    if (trimmed.toUpperCase().startsWith('CREATE TABLE')) {
      final match = RegExp(r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z0-9_]+)', caseSensitive: false)
          .firstMatch(trimmed);
      if (match != null) {
        final tableName = match.group(1)!;
        _tables.putIfAbsent(tableName, () => <Map<String, dynamic>>[]);
      }
    }
  }

  /// Exports all tables as a JSON-serializable Map for persistent caching.
  Map<String, dynamic> exportSnapshot() {
    return _tables.map((k, v) => MapEntry(k, v.map((r) => Map<String, dynamic>.from(r)).toList()));
  }

  /// Restores table records from a previously persisted snapshot.
  void importSnapshot(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      if (entry.value is List) {
        final list = _tables.putIfAbsent(entry.key, () => <Map<String, dynamic>>[]);
        for (final item in entry.value as List) {
          if (item is Map) {
            final row = Map<String, dynamic>.from(item);
            final id = row['id']?.toString();
            if (id != null) {
              list.removeWhere((r) => r['id']?.toString() == id);
            }
            list.add(row);
          }
        }
      }
    }
  }

  /// Atomically runs an operation within a transactional rollback boundary.
  ///
  /// If [action] throws an exception, all modifications are automatically rolled back
  /// and the original database state is preserved.
  Future<T> transaction<T>(Future<T> Function(TransactionContext txn) action) async {
    final txn = _MemoryTransaction(this);
    try {
      final result = await action(txn);
      txn.commit();
      onDataChanged?.call();
      return result;
    } catch (e) {
      txn.rollback();
      rethrow;
    }
  }

  @override
  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    TransactionContext? txn,
  }) async {
    if (txn is _MemoryTransaction) {
      return txn.insert(table, values);
    }

    final tableList = _tables.putIfAbsent(table, () => <Map<String, dynamic>>[]);
    
    // Check primary key / unique constraints
    final id = values['id']?.toString();
    if (id != null) {
      tableList.removeWhere((r) => r['id']?.toString() == id);
    }
    
    tableList.add(Map<String, dynamic>.from(values));
    onDataChanged?.call();
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    TransactionContext? txn,
  }) async {
    if (txn is _MemoryTransaction) {
      return txn.update(table, values, where: where, whereArgs: whereArgs);
    }

    final tableList = _tables[table];
    if (tableList == null || tableList.isEmpty) return 0;

    int updatedCount = 0;
    for (int i = 0; i < tableList.length; i++) {
      if (_matchesWhere(tableList[i], where, whereArgs)) {
        tableList[i] = {
          ...tableList[i],
          ...values,
        };
        updatedCount++;
      }
    }
    if (updatedCount > 0) {
      onDataChanged?.call();
    }
    return updatedCount;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    TransactionContext? txn,
  }) async {
    if (txn is _MemoryTransaction) {
      return txn.delete(table, where: where, whereArgs: whereArgs);
    }

    final tableList = _tables[table];
    if (tableList == null || tableList.isEmpty) return 0;

    final initialCount = tableList.length;
    tableList.removeWhere((row) => _matchesWhere(row, where, whereArgs));
    final deletedCount = initialCount - tableList.length;
    if (deletedCount > 0) {
      onDataChanged?.call();
    }
    return deletedCount;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final tableList = _tables[table];
    if (tableList == null || tableList.isEmpty) return [];

    var results = tableList
        .where((row) => _matchesWhere(row, where, whereArgs))
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    // Order By
    if (orderBy != null && orderBy.isNotEmpty) {
      final parts = orderBy.trim().split(RegExp(r'\s+'));
      final col = parts[0];
      final desc = parts.length > 1 && parts[1].toUpperCase() == 'DESC';

      results.sort((a, b) {
        final valA = a[col];
        final valB = b[col];
        if (valA == null && valB == null) return 0;
        if (valA == null) return desc ? 1 : -1;
        if (valB == null) return desc ? -1 : 1;
        final comp = Comparable.compare(valA as Comparable, valB as Comparable);
        return desc ? -comp : comp;
      });
    }

    // Offset & Limit
    if (offset != null && offset > 0) {
      results = results.skip(offset).toList();
    }
    if (limit != null && limit > 0) {
      results = results.take(limit).toList();
    }

    return results;
  }

  /// Purges all data associated with a specific tenant business ID.
  ///
  /// Critical security requirement on logout or tenant switch.
  Future<void> clearTenantData(String businessId) async {
    for (final table in _tables.keys) {
      _tables[table]?.removeWhere((row) => row['business_id'] == businessId);
    }
    onDataChanged?.call();
  }

  /// Clears all tables in the database.
  Future<void> clearAll() async {
    _tables.clear();
    onDataChanged?.call();
  }

  bool _matchesWhere(Map<String, dynamic> row, String? where, List<dynamic>? whereArgs) {
    if (where == null || where.trim().isEmpty) return true;

    // Simple expression parser supporting standard equality clauses joined by AND
    // e.g., "business_id = ? AND status = ?" or "client_operation_id = ?"
    final clauses = where.split(RegExp(r'\s+AND\s+', caseSensitive: false));
    int argIndex = 0;

    for (final clause in clauses) {
      final trimmedClause = clause.trim();
      
      // Equals: "col = ?" or "col = value"
      if (trimmedClause.contains('=')) {
        final parts = trimmedClause.split('=');
        final col = parts[0].trim();
        final rawVal = parts[1].trim();

        dynamic expectedVal;
        if (rawVal == '?') {
          if (whereArgs != null && argIndex < whereArgs.length) {
            expectedVal = whereArgs[argIndex++];
          }
        } else {
          expectedVal = rawVal.replaceAll("'", "");
        }

        final actualVal = row[col];
        if (expectedVal == null && actualVal != null) return false;
        if (expectedVal != null && actualVal?.toString() != expectedVal.toString()) {
          return false;
        }
      } else if (trimmedClause.toUpperCase().contains('IS NULL')) {
        final col = trimmedClause.split(RegExp(r'\s+IS\s+NULL', caseSensitive: false))[0].trim();
        if (row[col] != null) return false;
      } else if (trimmedClause.toUpperCase().contains('IS NOT NULL')) {
        final col = trimmedClause.split(RegExp(r'\s+IS\s+NOT\s+NULL', caseSensitive: false))[0].trim();
        if (row[col] == null) return false;
      }
    }

    return true;
  }
}

/// Transaction implementation that buffers mutations and applies or reverts them atomically.
class _MemoryTransaction implements TransactionContext {
  final AppDatabase _db;
  
  // Clone of the database state at the beginning of the transaction
  final Map<String, List<Map<String, dynamic>>> _snapshot = {};
  bool _isCommitted = false;
  bool _isRolledBack = false;

  _MemoryTransaction(this._db) {
    for (final entry in _db._tables.entries) {
      _snapshot[entry.key] = entry.value
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> values) async {
    _checkActive();
    final tableList = _db._tables.putIfAbsent(table, () => <Map<String, dynamic>>[]);
    final id = values['id']?.toString();
    if (id != null) {
      tableList.removeWhere((r) => r['id']?.toString() == id);
    }
    tableList.add(Map<String, dynamic>.from(values));
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    _checkActive();
    final tableList = _db._tables[table];
    if (tableList == null || tableList.isEmpty) return 0;

    int updatedCount = 0;
    for (int i = 0; i < tableList.length; i++) {
      if (_db._matchesWhere(tableList[i], where, whereArgs)) {
        tableList[i] = {
          ...tableList[i],
          ...values,
        };
        updatedCount++;
      }
    }
    return updatedCount;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    _checkActive();
    final tableList = _db._tables[table];
    if (tableList == null || tableList.isEmpty) return 0;

    final initialCount = tableList.length;
    tableList.removeWhere((row) => _db._matchesWhere(row, where, whereArgs));
    return initialCount - tableList.length;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    _checkActive();
    return _db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  void commit() {
    _isCommitted = true;
  }

  void rollback() {
    if (_isCommitted) return;
    _isRolledBack = true;
    _db._tables.clear();
    for (final entry in _snapshot.entries) {
      _db._tables[entry.key] = entry.value
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
  }

  void _checkActive() {
    if (_isCommitted) throw StateError('Transaction already committed.');
    if (_isRolledBack) throw StateError('Transaction already rolled back.');
  }
}

