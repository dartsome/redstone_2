library plugins;

import 'dart:mirrors';

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'dart:async';

//plugin - parameter provider

class FromJson {
  const FromJson();
}

void fromJsonPlugin(Manager manager) {
  manager.addParameterProvider(FromJson,
      (metadata, type, handlerName, paramName, req, injector) {
    if (req.bodyType != JSON) {
      throw new ErrorResponse(400, "content-type must be 'application/json'");
    }

    ClassMirror clazz = reflectClass(type);
    InstanceMirror obj = clazz.newInstance(const Symbol(""), const []);
    obj.invoke(#fromJson, [req.body]);
    return obj.reflectee;
  });
}

//test plugin

class User {
  String name;
  String username;

  void fromJson(Map json) {
    name = json["name"];
    username = json["username"];
  }

  Map toJson() {
    return {"name": name, "username": username};
  }

  String toString() => "name: $name username: $username";
}

@Route("/user", methods: const [POST])
String printUser(@FromJson() User user) => user.toString();

//plugin - response processor

class ToJson {
  const ToJson();
}

void toJsonPlugin(Manager manager) {
  manager.addResponseProcessor(ToJson,
      (metadata, handlerName, value, injector) {
    if (value == null) {
      return value;
    }
    return (value as dynamic).toJson();
  });
}

//test plugin

@Route("/user/find")
@ToJson()
User returnUser() {
  var user = new User();
  user.name = "name";
  user.username = "username";
  return user;
}

//plugin - add routes, interceptors and error handlers

void testPlugin(Manager manager) {
  Route route = new Route("/route/:arg");
  Interceptor interceptor = new Interceptor("/route/.+");

  Route routeError = new Route("/error");
  ErrorHandler errorHandler = new ErrorHandler(500);

  manager.addRoute(route, "testRoute", (injector, request) {
    return request.urlParameters["arg"];
  });

  manager.addInterceptor(interceptor, "testInterceptor",
      (injector, request) async {
    await chain.next();
    return response
        .readAsString()
        .then((resp) => new shelf.Response.ok("interceptor $resp"));
  });

  manager.addRoute(routeError, "testError", (injector, request) {
    throw "error";
  });

  manager.addErrorHandler(errorHandler, "testErrorHandler",
      (injector, request) {
    return new shelf.Response.internalServerError(body: "error_handler");
  });
}

//plugin - add route wrappers

class Wrap {
  final String msg;
  const Wrap([this.msg = "response"]);
}

void wrapperPlugin(Manager manager) {
  manager.addRouteWrapper(Wrap, (wrap, injector, request, route) async {
    var resp = await route(injector, request);

    if (resp is shelf.Response) return resp;

    return "${wrap.msg}: $resp";
  }, includeGroups: true);
}

@Route("/test_wrapper")
@Wrap()
String testWrapper() => "target executed";

@Group("/test_group_wrapper")
@Wrap()
class TestGroupWrapper {
  @Route("/test_wrapper")
  String testWrapper() => "target executed";
}

@Group("/test_method_wrapper")
class TestMethodWrapper {
  @Route("/test_wrapper")
  @Wrap()
  String testWrapper() => "target executed";
}

@Group('/test_wrapper')
class TestRedirectWrapper {
  @Route("/redirect")
  @Wrap("REDIRECT")
  Future<shelf.Response> testWrapperRedirect() =>
      chain.forward('/test_wrapper/b');

  @Route("/b")
  @Wrap("response")
  String testWrapperB() => "target executed";
}

//test scanning

class TestAnnotation {
  const TestAnnotation();
}

@TestAnnotation()
void annotatedFunction() {}

@TestAnnotation()
class AnnotatedClass {
  @TestAnnotation()
  void annotatedMethod() {}
}

//Helper class to handle mirror objects
class CapturedType {
  Symbol typeName;
  Object metadata;

  CapturedType(AnnotatedType annotatedType) {
    typeName = annotatedType.mirror.simpleName;
    metadata = annotatedType.metadata;
  }

  CapturedType.fromValues(this.typeName, this.metadata);

  bool operator ==(dynamic other) {
    return other is CapturedType &&
        other.typeName == typeName &&
        other.metadata == metadata;
  }

  int get hashCode {
    int a = typeName == null ? 0 : typeName.hashCode;
    int b = metadata == null ? 0 : metadata.hashCode;
    return (a & 0x1fffffff) + (b & 0x1fffffff);
  }

  String toString() => "@$metadata $typeName";
}
