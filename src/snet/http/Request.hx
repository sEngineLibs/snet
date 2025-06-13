package snet.http;

import haxe.io.Bytes;

using StringTools;
using snet.http.Request.MapExt;

class MapExt {
	public static function isEmpty<L, R>(x:Map<L, R>)
		return [for (k in x.keys()) k].length == 0;
}

@:forward()
abstract Request(RequestData) from RequestData {
	@:from
	public static function fromBytes(raw:Bytes):Request {
		var str = raw.toString();
		var lines = str.split("\r\n");
		if (lines.length == 1)
			lines = str.split("\n");

		var requestLine = lines.shift();
		if (requestLine == null || requestLine.trim() == "")
			return null;

		var parts = requestLine.split(" ");
		var method = parts[0];
		var fullPath = parts.length > 1 ? parts[1] : "/";
		var queryIndex = fullPath.indexOf("?");
		var path = queryIndex >= 0 ? fullPath.substr(0, queryIndex) : fullPath;
		var query = queryIndex >= 0 ? fullPath.substr(queryIndex + 1) : null;
		var version = parts.length > 2 ? parts[2] : "HTTP/1.1";

		var headers:Map<Header, String> = [];
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

		var headerEnd = str.indexOf("\r\n\r\n");
		var bodyStart = headerEnd + 4;
		var contentLength = headers.exists("Content-Length") ? Std.parseInt(headers.get("Content-Length")) : (raw.length - bodyStart);
		var bodyBytes = raw.sub(bodyStart, contentLength);
		var body = bodyBytes.toString();

		var contentType = headers.get("Content-Type");
		var params:Map<String, String> = null;

		if (query != null && method == "GET")
			params = parseURLEncoded(query);
		else if (contentType != null && contentType.indexOf("application/x-www-form-urlencoded") != -1)
			params = parseURLEncoded(body);

		return {
			method: method,
			path: path,
			version: version,
			headers: headers,
			cookies: cookies,
			params: params,
			data: (params == null ? body : null),
			bytes: (params == null ? bodyBytes : null)
		};
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
	public function toBytes():Bytes {
		var sb = new StringBuf();
		sb.add('${this.method} ${this.path} ${this.version}\r\n');

		// cookies
		if (this.cookies != null && !this.cookies.isEmpty()) {
			var c = [];
			for (k in this.cookies.keys())
				c.push('$k=${this.cookies.get(k)}');
			sb.add('Cookie: ${c.join("; ")}\r\n');
		}

		// body
		var body:Bytes = null;
		if (this.data != null) {
			body = Bytes.ofString(this.data);
			if (!this.headers.exists("Content-Type"))
				this.headers.set("Content-Type", "text/plain; charset=utf-8");
		} else if (this.params != null && !this.params.isEmpty()) {
			var encoded = [];
			for (k in this.params.keys())
				encoded.push(k.urlEncode() + "=" + this.params.get(k).urlEncode());
			var encodedStr = encoded.join("&");
			body = Bytes.ofString(encodedStr);
			this.headers.set("Content-Type", "application/x-www-form-urlencoded");
		} else if (this.bytes != null) {
			body = this.bytes;
			if (!this.headers.exists("Content-Type"))
				this.headers.set("Content-Type", "application/octet-stream");
		}

		if (body != null && !this.headers.exists("Content-Length"))
			this.headers.set("Content-Length", '${body.length}');

		// headers
		for (k in this.headers.keys())
			sb.add('$k: ${this.headers.get(k)}\r\n');
		sb.add("\r\n");

		var headerBytes = Bytes.ofString(sb.toString());

		if (body == null)
			return headerBytes;

		var full = Bytes.alloc(headerBytes.length + body.length);
		full.blit(0, headerBytes, 0, headerBytes.length);
		full.blit(headerBytes.length, body, 0, body.length);
		return full;
	}
}

@:structInit
private class RequestData {
	public var path:String = "/";
	public var method:haxe.http.HttpMethod = Get;
	public var version:String = "HTTP/1.1";
	public var headers:Map<Header, String> = [];
	public var data:String = null;
	public var bytes:Bytes = null;
	public var params:Map<String, String> = [];
	public var cookies:Map<String, String> = [];
}
