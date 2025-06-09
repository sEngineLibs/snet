package snet.http;

import haxe.io.Bytes;

using StringTools;
using snet.http.Http.MapExt;

class MapExt {
	public static function isEmpty<L, R>(x:Map<L, R>)
		return [for (k in x.keys()) k].length == 0;
}

typedef HttpMethod = haxe.http.HttpMethod;
class HttpError extends haxe.Exception {}

enum abstract HttpHeader(String) from String to String {
	// General headers
	var CACHE_CONTROL = "Cache-Control";
	var CONNECTION = "Connection";
	var DATE = "Date";
	var PRAGMA = "Pragma";
	var TRAILER = "Trailer";
	var TRANSFER_ENCODING = "Transfer-Encoding";
	var UPGRADE = "Upgrade";
	var VIA = "Via";
	var WARNING = "Warning";

	// Request headers
	var ACCEPT = "Accept";
	var ACCEPT_CHARSET = "Accept-Charset";
	var ACCEPT_ENCODING = "Accept-Encoding";
	var ACCEPT_LANGUAGE = "Accept-Language";
	var AUTHORIZATION = "Authorization";
	var EXPECT = "Expect";
	var FROM = "From";
	var HOST = "Host";
	var IF_MATCH = "If-Match";
	var IF_MODIFIED_SINCE = "If-Modified-Since";
	var IF_NONE_MATCH = "If-None-Match";
	var IF_RANGE = "If-Range";
	var IF_UNMODIFIED_SINCE = "If-Unmodified-Since";
	var MAX_FORWARDS = "Max-Forwards";
	var PROXY_AUTHORIZATION = "Proxy-Authorization";
	var RANGE = "Range";
	var REFERER = "Referer";
	var TE = "TE";
	var USER_AGENT = "User-Agent";

	// Response headers
	var ACCEPT_RANGES = "Accept-Ranges";
	var AGE = "Age";
	var ETAG = "ETag";
	var LOCATION = "Location";
	var PROXY_AUTHENTICATE = "Proxy-Authenticate";
	var RETRY_AFTER = "Retry-After";
	var SERVER = "Server";
	var VARY = "Vary";
	var WWW_AUTHENTICATE = "WWW-Authenticate";

	// Entity headers
	var ALLOW = "Allow";
	var CONTENT_ENCODING = "Content-Encoding";
	var CONTENT_LANGUAGE = "Content-Language";
	var CONTENT_LENGTH = "Content-Length";
	var CONTENT_LOCATION = "Content-Location";
	var CONTENT_MD5 = "Content-MD5";
	var CONTENT_RANGE = "Content-Range";
	var CONTENT_TYPE = "Content-Type";
	var EXPIRES = "Expires";
	var LAST_MODIFIED = "Last-Modified";

	// WebSocket headers
	var SEC_WEBSOCKET_KEY = "Sec-WebSocket-Key";
	var SEC_WEBSOCKET_ACCEPT = "Sec-WebSocket-Accept";
	var SEC_WEBSOCKET_VERSION = "Sec-WebSocket-Version";
	var SEC_WEBSOCKET_PROTOCOL = "Sec-WebSocket-Protocol";
	var SEC_WEBSOCKET_EXTENSIONS = "Sec-WebSocket-Extensions";
	var X_WEBSOCKET_REJECT_REASON = "X-WebSocket-Reject-Reason";

	// CORS headers
	var ORIGIN = "Origin";
	var ACCESS_CONTROL_ALLOW_ORIGIN = "Access-Control-Allow-Origin";
	var ACCESS_CONTROL_ALLOW_METHODS = "Access-Control-Allow-Methods";
	var ACCESS_CONTROL_ALLOW_HEADERS = "Access-Control-Allow-Headers";
	var ACCESS_CONTROL_EXPOSE_HEADERS = "Access-Control-Expose-Headers";
	var ACCESS_CONTROL_MAX_AGE = "Access-Control-Max-Age";
	var ACCESS_CONTROL_ALLOW_CREDENTIALS = "Access-Control-Allow-Credentials";
	var ACCESS_CONTROL_REQUEST_METHOD = "Access-Control-Request-Method";
	var ACCESS_CONTROL_REQUEST_HEADERS = "Access-Control-Request-Headers";

	// Security headers
	var STRICT_TRANSPORT_SECURITY = "Strict-Transport-Security";
	var CONTENT_SECURITY_POLICY = "Content-Security-Policy";
	var X_CONTENT_TYPE_OPTIONS = "X-Content-Type-Options";
	var X_FRAME_OPTIONS = "X-Frame-Options";
	var X_XSS_PROTECTION = "X-XSS-Protection";
	var PERMISSIONS_POLICY = "Permissions-Policy";
	var REFERRER_POLICY = "Referrer-Policy";

	// Custom or deprecated but useful
	var X_REQUESTED_WITH = "X-Requested-With";
	var X_FORWARDED_FOR = "X-Forwarded-For";
	var X_FORWARDED_PROTO = "X-Forwarded-Proto";
	var X_REAL_IP = "X-Real-IP";
	var X_POWERED_BY = "X-Powered-By";
	var DNT = "DNT"; // Do Not Track
}

@:forward()
abstract HttpRequest(HttpRequestData) from HttpRequestData {
	@:from
	public static function fromString(raw:String):HttpRequest {
		var lines = raw.split("\r\n");
		if (lines.length == 1)
			lines = raw.split("\n");

		var requestLine = lines.shift();
		if (requestLine == null || requestLine.trim() == "")
			return null;

		var parts = requestLine.split(" ");
		var method = parts[0];
		var path = parts.length > 1 ? parts[1] : "/";
		var version = parts.length > 2 ? parts[2] : "HTTP/1.1";

		var headers:Map<String, String> = [];
		var cookies:Map<String, String> = [];
		while (lines.length > 0) {
			var line = lines.shift();
			if (line == "")
				break;
			var sep = line.indexOf(":");
			if (sep > -1) {
				var key = line.substr(0, sep).trim();
				var value = line.substr(sep + 1).trim();
				headers.set(key, value);
				if (key.toLowerCase() == "cookie")
					for (pair in value.split(";")) {
						var kv = pair.split("=");
						if (kv.length == 2)
							cookies.set(kv[0].trim(), kv[1].trim());
					}
			}
		}

		var body = lines.join("\r\n");
		var contentType = headers.get("Content-Type");
		var params:Map<String, String> = null;
		var files:Map<String, Bytes> = null;

		if (contentType != null && contentType.indexOf("application/x-www-form-urlencoded") != -1)
			params = parseURLEncoded(body);
		else if (contentType != null && contentType.indexOf("multipart/form-data") != -1) {
			var boundary = "--" + contentType.split("boundary=")[1];
			final parts = body.split(boundary).slice(1, -1);
			params = new Map();
			files = new Map();

			for (part in parts) {
				var p = part.split("\r\n\r\n");
				if (p.length != 2)
					continue;
				var headersBlock = p[0].trim();
				var value = p[1].trim();

				var name = null;
				var filename = null;
				for (h in headersBlock.split("\r\n"))
					if (h.toLowerCase().startsWith("content-disposition"))
						for (kv in h.split(";")) {
							var kvp = kv.split("=");
							if (kvp.length == 2) {
								var k = kvp[0].trim(),
									v = kvp[1].trim().replace("\"", "");
								if (k == "name")
									name = v;
								if (k == "filename")
									filename = v;
							}
						}

				if (name != null)
					if (filename != null)
						files.set(name, Bytes.ofString(value));
					else
						params.set(name, value);
			}
		}

		return {
			method: method,
			path: path,
			version: version,
			headers: headers,
			data: body,
			params: params,
			cookies: cookies,
			files: files
		}
	}

	static function parseURLEncoded(body:String):Map<String, String> {
		var map = new Map();
		for (pair in body.split("&")) {
			var eq = pair.indexOf("=");
			if (eq > -1)
				map.set(pair.substr(0, eq).urlDecode(), pair.substr(eq + 1).urlDecode());
		}
		return map;
	}

	@:to
	public function toString():String {
		var sb = new StringBuf();
		sb.add((this.method != null ? this.method : "GET") + " " + (this.path != null ? this.path : "/") + " "
			+ (this.version != null ? this.version : "HTTP/1.1") + "\r\n");

		// cookies
		if (this.cookies != null && !this.cookies.isEmpty()) {
			var c = [];
			for (k in this.cookies.keys())
				c.push(k + "=" + this.cookies.get(k));
			sb.add("Cookie: " + c.join("; ") + "\r\n");
		}

		// headers
		if (this.headers != null) {
			for (k in this.headers.keys())
				sb.add(k + ": " + this.headers.get(k) + "\r\n");
		}
		sb.add("\r\n");

		// body
		if (this.data != null) {
			sb.add(this.data);
		} else if (this.params != null) {
			var pairs = [];
			for (k in this.params.keys())
				pairs.push(k.urlEncode() + "=" + this.params.get(k).urlEncode());
			sb.add(pairs.join("&"));
		} else if (this.files != null && !this.files.isEmpty()) {
			final boundary = "----WebKitFormBoundary" + Math.floor(Math.random() * 1000000);
			this.headers.set("Content-Type", "multipart/form-data; boundary=" + boundary);

			for (name in this.params.keys()) {
				sb.add("--" + boundary + "\r\n");
				sb.add('Content-Disposition: form-data; name="' + name + '"\r\n\r\n');
				sb.add(this.params.get(name) + "\r\n");
			}

			for (fname in this.files.keys()) {
				sb.add("--" + boundary + "\r\n");
				sb.add('Content-Disposition: form-data; name="' + fname + '"; filename="' + fname + '"\r\n');
				sb.add("Content-Type: application/octet-stream\r\n\r\n");
				sb.add(this.files.get(fname).toString() + "\r\n");
			}

			sb.add("--" + boundary + "--\r\n");
		}

		return sb.toString();
	}
}

@:forward()
abstract HttpResponse(HttpResponseData) from HttpResponseData {
	@:from
	public static function fromString(raw:String):HttpResponse {
		var lines = raw.split("\r\n");
		if (lines.length == 0)
			return {
				status: 0,
				version: "HTTP/1.1",
				statusText: "Error",
				headers: [],
				error: "Empty response"
			};

		var statusLine = lines.shift();
		var parts = statusLine.split(" ");
		var version = parts[0];
		var status = Std.parseInt(parts[1]);
		var statusText = parts.slice(2).join(" ");

		var headers = new Map<String, String>();
		var cookies = new Map<String, String>();
		while (lines.length > 0) {
			var line = lines.shift();
			if (line == "")
				break;
			var sep = line.indexOf(":");
			if (sep > -1) {
				var key = line.substr(0, sep).trim();
				var value = line.substr(sep + 1).trim();
				headers.set(key, value);
				if (key.toLowerCase() == "set-cookie") {
					var kv = value.split("=");
					if (kv.length >= 2)
						cookies.set(kv[0], kv[1].split(";")[0]);
				}
			}
		}

		var body = "";
		if (headers.get("Transfer-Encoding") == "chunked")
			body = parseChunkedBody(lines);
		else
			body = lines.join("\r\n");

		return {
			version: version,
			status: status,
			statusText: statusText,
			headers: headers,
			cookies: cookies,
			data: body
		};
	}

	static function parseChunkedBody(lines:Array<String>):String {
		var result = new StringBuf();
		while (lines.length > 0) {
			var sizeLine = lines.shift();
			if (sizeLine == null)
				break;
			var size = Std.parseInt("0x" + sizeLine.trim());
			if (size == 0)
				break;

			var chunk = "";
			while (chunk.length < size && lines.length > 0) {
				chunk += lines.shift() + "\r\n";
			}
			result.add(chunk.substr(0, size));
			if (lines.length > 0)
				lines.shift(); // remove \r\n
		}
		return result.toString();
	}

	@:to
	public function toString():String {
		var sb = new StringBuf();
		sb.add((this.version != null ? this.version : "HTTP/1.1")
			+ " "
			+ this.status
			+ " "
			+ (this.statusText != null ? this.statusText : "OK")
			+ "\r\n");

		// cookies
		if (this.cookies != null) {
			for (k in this.cookies.keys())
				sb.add("Set-Cookie: " + k + "=" + this.cookies.get(k) + "; Path=/\r\n");
		}

		// headers
		if (this.headers != null)
			for (k in this.headers.keys())
				sb.add(k + ": " + this.headers.get(k) + "\r\n");

		sb.add("\r\n");

		// body
		if (this.data != null) {
			if (this.headers != null && this.headers.get("Transfer-Encoding") == "chunked") {
				var chunkSize = 8;
				var i = 0;
				while (i < this.data.length) {
					var chunk = this.data.substr(i, chunkSize);
					sb.add(StringTools.hex(chunk.length) + "\r\n");
					sb.add(chunk + "\r\n");
					i += chunk.length;
				}
				sb.add("0\r\n\r\n"); // end chunk
			} else
				sb.add(this.data);
		}

		return sb.toString();
	}
}

@:structInit
private class HttpRequestData {
	public var path:String = "/";
	public var method:HttpMethod = Get;
	public var version:String = "HTTP/1.1";
	public var headers:Map<HttpHeader, String> = [];
	public var data:String = null;
	public var params:Map<String, String> = [];
	public var cookies:Map<String, String> = [];
	public var files:Map<String, Bytes> = [];
}

@:structInit
private class HttpResponseData {
	public var status:Int = 200;
	public var statusText:String = "OK";
	public var version:String = null;
	public var headers:Map<HttpHeader, String> = [];
	public var data:String = null;
	public var error:String = null;
	public var cookies:Map<String, String> = [];
}
