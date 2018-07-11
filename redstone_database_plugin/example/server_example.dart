// Copyright (c) 2016, the DartSome project authors.  Please see the AUTHORS file

import 'dart:convert';
import 'dart:async';

import 'package:logging/logging.dart';
import 'package:redstone/redstone.dart' as app;
import 'package:redstone_database_plugin/database.dart';
import 'package:redstone_database_plugin/plugin.dart';
import 'package:serializer/codecs.dart';
import 'package:serializer/serializer.dart';

import 'server_example.codec.dart';

Map _db = new Map();

class MapDbManager extends DatabaseManager<Map> {
  int index = 0;

  MapDbManager(Serializer serializer) : super(serializer);

  Future<Map> getConnection() async => _db;
  void closeConnection(Map connection, {dynamic error}) {}
}

@serializable
class User {
  String id;
  String name;
}

Map get dbConn => app.request.attributes['dbConn'];

var serializer = new Serializer(codec: json)..addAllTypeCodecs(example_server_example_codecs);
var dbManager = new MapDbManager(serializer);

main() {
  app.addPlugin(getDatabasePlugin(serializer, dbManager, null));
  app.setupConsoleLog(Level.INFO);
  app.start();
}

@app.Route("/users", methods: const [app.POST])
@Encode()
User addUser(@Decode() User user) {
  app.redstoneLogger.info("POST /users ${user.name}");

  user.id = (dbManager.index++).toString();
  dbConn[user.id] = user;

  return user;
}

@app.Route("/users", methods: const [app.GET])
@Encode()
List<User> getUsers() {
  app.redstoneLogger.info("GET /users");
  return new List<User>.from(dbConn.values);
}

@app.Route("/users/:id", methods: const [app.GET])
@Encode()
User getUser(String id) {
  app.redstoneLogger.info("GET /users/$id");
  return dbConn[id];
}
