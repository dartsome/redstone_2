// Copyright (c) 2016, the DartSome project authors.  Please see the AUTHORS file

import 'dart:mirrors';
import 'package:di/di.dart';
import 'package:redstone_database_plugin/database.dart';
import 'package:redstone/redstone.dart';
import 'package:serializer/core.dart';
import 'package:shelf/shelf.dart' as shelf;

/// An Exception when errors occur for Decode and Encode annotations
class DbSerializationException implements Exception {
  final Exception exception;
  const DbSerializationException(this.exception);
  String toString() => runtimeType.toString() + ": " + exception.toString();
}

/**
 * An annotation to define a target parameter.
 *
 * Parameters annotated with this annotation
 * can be decoded from the request's body or
 * query parameters.
 *
 * If [fromQueryParams] is true, then this parameter will be decoded from
 * the query parameters.
 *
 * Example:
 *
 *     @app.Route('/services/users/add', methods: const[app.POST])
 *     addUser(@Decode() User user) {
 *       ...
 *     }
 */
class Decode {
  final bool fromQueryParams;
  final bool useTypeInfo;
  const Decode({bool this.fromQueryParams: false, bool this.useTypeInfo});
}

/**
 * An annotation to define routes whose response
 * can be encoded.
 *
 * Example:
 *
 *     @app.Route('/services/users/list')
 *     @Encode()
 *     List<User> listUsers() {
 *       ...
 *     }
 *
 */
class Encode {
  final bool useTypeInfo;
  final bool withTypeInfo;
  const Encode({bool this.useTypeInfo, bool this.withTypeInfo});
}

/**
 * Interface to log date decode and encode
 */
abstract class DataLogger {
  void decode(Request request, String paramName, Type type, data);
  void encode(Request request, Type type, data);
}

/**
 * Get and configure the redstone_database plugin.
 *
 * If [db] is provided, then the plugin will initialize a database connection for
 * every request, and save it as a request attribute. If [dbPathPattern] is
 * provided, then the database connection will be initialized only for routes
 * that match the pattern.
 *
 * Usage:
 *
 *      import 'package:redstone/redstone.dart' as app;
 *      import 'package:redstone_database_plugin/plugin.dart';
 *
 *      main() {
 *
 *        app.addPlugin(getDatabasePlugin());
 *        ...
 *        app.start();
 *
 *      }
 *
 */
RedstonePlugin getDatabasePlugin(Serializer serializer, DatabaseManager db, DataLogger logger,
    [String dbPathPattern = r'/.*']) {
  return (Manager manager) {
    if (db != null) {
      manager.addInterceptor(new Interceptor(dbPathPattern), "database connection manager",
          (Injector injector, Request request) async {
        var conn = await db.getConnection();
        request.attributes[dbConnectionAttribute] = conn;
        var resp = await chain.next();
        db.closeConnection(conn, error: chain.error);
        return resp;
      });

      manager.addParameterProvider(Decode,
          (dynamic metadata, Type paramType, String handlerName, String paramName, Request request, Injector injector) {
        var data;
        var decode = metadata as Decode;
        if (decode.fromQueryParams) {
          var params = request.queryParameters;
          data = {};
          params.forEach((String key, List<String> value) {
            data[key] = value[0];
          });
        } else {
          data = request.body;
        }

        try {
          if (logger != null) {
            logger.decode(request, paramName, paramType, data);
          }
          if (request.bodyType == JSON || request.bodyType == FORM || decode.fromQueryParams) {
            if (data is Map) {
              return serializer.fromMap(data, type: paramType, useTypeInfo: decode.useTypeInfo);
            } else if (data is List) {
              paramType = reflectType(paramType).typeArguments.first.reflectedType;
              return serializer.fromList(data, type: paramType, useTypeInfo: decode.useTypeInfo);
            }
          }
          if (request.bodyType == BINARY) {
            data = new String.fromCharCodes(data as Iterable<int>);
          }
          return serializer.decode(data, type: paramType, useTypeInfo: decode.useTypeInfo);
        } catch (e) {
          throw new DbSerializationException(e);
        }
      });

      manager.addResponseProcessor(Encode, (dynamic metadata, String handlerName, Object response, Injector injector) {
        if (response == null || response is shelf.Response) {
          return response;
        }

        var paramType = response.runtimeType;
        try {
          var encode = metadata as Encode;
          var json =
              serializer.toPrimaryObject(response, useTypeInfo: encode.useTypeInfo, withTypeInfo: encode.withTypeInfo);
          if (logger != null) {
            logger.encode(request, paramType, json);
          }
          return json;
        } catch (e) {
          throw new DbSerializationException(e);
        }
      }, includeGroups: true);
    }
  };
}
