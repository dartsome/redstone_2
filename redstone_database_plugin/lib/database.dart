// Copyright (c) 2016, the DartSome project authors.  Please see the AUTHORS file

import 'dart:async';
import 'package:serializer/core.dart';

const dbConnectionAttribute = "dbConn";

/// Manage connections with a database.
abstract class DatabaseManager<T> {
  final Serializer serializer;

  DatabaseManager(this.serializer);

  Future<T> getConnection();

  void closeConnection(T connection, {dynamic error});
}
