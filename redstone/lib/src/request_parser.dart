library redstone.src.request_parser;

import 'dart:io';
import 'dart:async';
import 'dart:convert' as conv;

import 'package:shelf/shelf.dart' as shelf;
import 'package:http_server/src/http_body_impl.dart';

import 'constants.dart';
import 'request.dart';

class RequestParser implements Request {
  final HttpRequest httpRequest;
  shelf.Request _shelfRequest;

  Map<String, String> _headers = null;
  Map<String, List<String>> _queryParameters = null;
  Map _attributes = null;

  ContentType _contentType = null;
  BodyType _bodyType = null;
  bool _isMultipart = null;
  dynamic _body = null;

  Credentials _credentials = null;

  final List<String> _skipParseOnMethods = ['GET'];

  RequestParser(this.httpRequest);

  Future parseBody() async {
    if (_bodyType == null) {
      _parseBodyType();
    }

    if (_body == null && !_skipParseOnMethods.contains(this.httpRequest.method)) {
      var httpBody = await HttpBodyHandlerImpl.process(_shelfRequest.read(),
          new _HttpHeaders(new Map.from(headers), _contentType), encoding);

      _body = httpBody.body;
    }

    return null;
  }

  @override
  Map get attributes => _attributes;

  @override
  Map<String, String> urlParameters = null;

  conv.Encoding encoding = conv.utf8;

  @override
  dynamic get body => _body;

  @override
  BodyType get bodyType {
    if (_bodyType != null) {
      return _bodyType;
    }

    _parseBodyType();
    return _bodyType;
  }

  @override
  Map get headers => _headers;

  @override
  bool get isMultipart {
    if (_isMultipart != null) {
      return _isMultipart;
    }

    _parseBodyType();
    return _isMultipart;
  }

  @override
  String get method => _shelfRequest.method;

  @override
  Credentials parseAuthorizationHeader() {
    if (_credentials != null) {
      return _credentials;
    }
    String authorization = headers[HttpHeaders.authorizationHeader];
    if (authorization != null) {
      List<String> tokens = authorization.split(" ");
      if ("Basic" == tokens[0]) {
        String auth =
            conv.utf8.decode(conv.base64Decode(tokens[1]));
        int idx = auth.indexOf(":");
        if (idx > 0) {
          String username = auth.substring(0, idx);
          String password = auth.substring(idx + 1);
          _credentials = new Credentials(username, password);
          return _credentials;
        }
      }
    }
    return null;
  }

  @override
  Map<String, List<String>> get queryParameters {
    if (_queryParameters != null) {
      return _queryParameters;
    }

    _splitQueryString();
    return _queryParameters;
  }

  @override
  Uri get requestedUri => _shelfRequest.requestedUri;

  @override
  String get handlerPath => _shelfRequest.handlerPath;

  @override
  HttpSession get session => httpRequest.session;

  @override
  shelf.Request get shelfRequest => _shelfRequest;

  void set shelfRequest(shelf.Request shelfRequest) {
    if (this.shelfRequest == null) {
      _attributes = new Map.from({}..addAll(shelfRequest.context));
    }
    _headers = new Map.from(shelfRequest.headers);
    _shelfRequest = shelfRequest;
  }

  @override
  Uri get url => _shelfRequest.url;

  void _parseBodyType() {
    if (_contentType == null) {
      _parseContentType();
    }
    if (_contentType == null) {
      _bodyType = BINARY;
      _isMultipart = false;
      return;
    }
    switch (_contentType.primaryType) {
      case "text":
        _bodyType = TEXT;
        _isMultipart = false;
        break;
      case "application":
        switch (_contentType.subType) {
          case "json":
            _bodyType = JSON;
            _isMultipart = false;
            break;
          case "x-www-form-urlencoded":
            _bodyType = FORM;
            _isMultipart = false;
            break;
          default:
            _isMultipart = false;
            _bodyType = BINARY;
            break;
        }
        break;
      case "multipart":
        _isMultipart = true;
        switch (_contentType.subType) {
          case "form-data":
            _bodyType = FORM;
            break;
        }
        break;
      default:
        _isMultipart = false;
        _bodyType = BINARY;
        break;
    }
  }

  void _parseContentType() {
    var ct = headers["content-type"];
    if (ct == null) {
      _contentType = ContentType.binary;
      return;
    }

    _contentType = ContentType.parse(ct);
  }

  void _splitQueryString() {
    Map<String,List<String>> params = url.query.split("&").fold({}, (map,
        element) {
      int index = element.indexOf("=");
      if (index == -1) {
        if (element != "") {
          var key = Uri.decodeQueryComponent(element, encoding: encoding);
          var values = map[key];
          if (values == null) {
            values = [];
            map[key] = values;
          }
          values.add("");
        }
      } else if (index != 0) {
        var key = Uri.decodeQueryComponent(element.substring(0, index),
            encoding: encoding);
        var value = Uri.decodeQueryComponent(element.substring(index + 1),
            encoding: encoding);
        var values = map[key];
        if (values == null) {
          values = [];
          map[key] = values;
        }
        values.add(value);
      }
      return map;
    });

    _queryParameters = params;
  }
}

class _HttpHeaders implements HttpHeaders {
  final Map<String, String> headers;
  ContentType _contentType;

  _HttpHeaders(this.headers, this._contentType);

  @override
  List<String> operator [](String name) {
    return headers[name].split(";");
  }

  @override
  ContentType get contentType => _contentType;

  @override
  void forEach(void f(String name, List<String> values)) {
    headers.forEach((k, v) => f(k, v.split(";")));
  }

  @override
  String value(String name) {
    return headers[name];
  }

  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
