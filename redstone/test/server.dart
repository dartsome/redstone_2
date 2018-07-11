library server;

//import 'dart:convert' as conv;
//import 'dart:async';
//import 'dart:mirrors';

import 'package:logging/logging.dart';
//import 'package:test/test.dart';

//import 'package:di/di.dart';
import 'package:redstone/redstone.dart';
//import 'package:shelf/shelf.dart' as shelf;

// These appear to be unused but are dynamically loaded and must be present.
//import 'services/routes.dart' as yo;
//import 'services/type_serialization.dart';
//import 'services/arguments.dart';
//import 'services/errors.dart';
//import 'services/interceptors.dart';
//import 'services/dependency_injection.dart';
// ignore: unused_import
import 'services/install_lib.dart';
//import 'services/plugins.dart';
//import 'services/inspect.dart';

void main() {
  showErrorPage = false;
  setupConsoleLog(Level.ALL);
  redstoneSetUp([#install_lib]);

//  addModule(new Module()..bind(A)..bind(B)..bind(C));

  start();
}
