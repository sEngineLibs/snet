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
	public static function fromString(raw:String):Request {
		var lines = raw.split("\r\n");
		if (lines.length == 1)
			lines = raw.split("\n");

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

		var body = lines.join("\r\n");
		var contentType = headers.get("Content-Type");
		var params:Map<String, String> = null;
		if (query != null && method == "GET")
			params = parseURLEncoded(query);
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

@:structInit
private class RequestData {
	public var path:String = "/";
	public var method:haxe.http.HttpMethod = Get;
	public var version:String = "HTTP/1.1";
	public var headers:Map<Header, String> = [];
	public var data:String = null;
	public var params:Map<String, String> = [];
	public var cookies:Map<String, String> = [];
	public var files:Map<String, Bytes> = [];
}
