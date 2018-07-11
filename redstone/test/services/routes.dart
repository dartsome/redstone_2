library routes;

import 'dart:async';
import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Route("/path/:subpath*")
String mainRoute() => "main_route";

@Route("/path/subpath")
String subRoute() => "sub_route";

@Route("/path2/:param*")
String mainRouteWithParam(String param) => param;

@Route("/handler_by_method")
String getHandler() => "get_handler";

@Route("/handler_by_method", methods: const [POST])
String postHandler() => "post_handler";

@Route("/change_status_code", statusCode: 201)
String changeStatusCode() => "response";

@Group("")
class ServiceGroup {
  @Route("/group")
  String defaultRoute() => "default_route";

  @Route("/group.json")
  String defaultRouteJson() => "default_route_json";

  @Route("/group", methods: const [POST])
  String defaultRoutePost() => "default_route_post";

  @Interceptor("/group/path(/.*)?")
  Future<shelf.Response> interceptor() async {
    await chain.next();
    var resp = await response.readAsString();
    return new shelf.Response.ok("interceptor $resp");
  }

  @Route("/group/path/:subpath*")
  String mainRoute() => "main_route";

  @Route("/group/path/subpath")
  String subRoute() => "sub_route";

  @Route("/group/change_status_code", statusCode: 201)
  String changeStatusCode() => "response";
}

// ignore: one_member_abstracts
abstract class Info {
  @Route("/info")
  String info();
}

// ignore: one_member_abstracts
abstract class Version {
  @Route("/version")
  String version();
}

@Group("/mixed")
class MixedServiceGroup extends ServiceGroup with Info, Version {
  String info() => "info";
  String version() => "version";

  @Route("/change_status_code", statusCode: 202)
  String changeStatusCode() => "mixed response";
}
