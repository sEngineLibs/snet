package snet.http;

import haxe.io.Bytes;
import sasync.Lazy;
import sasync.Async;
import snet.internal.Socket;
import snet.internal.Client;

using StringTools;
using snet.http.Requests.MapExt;

class MapExt {
	public static function isEmpty<L, R>(x:Map<L, R>)
		return [for (k in x.keys()) k].length == 0;
}

class HttpError extends haxe.Exception {}

class Requests {
	@async public static function request(url:String, ?request:HttpRequest, timeout:Float = 10.0, ?cert:Certificate) {
		var info = parseURL(url);
		if (info == null)
			throw new HttpError('Invalid URL: $url');

		if (info.isSecure)
			cert = cert ?? {
				cert: SecureCertificate.loadDefaults(),
				key: null,
				verify: false
			}
		else
			cert = null;

		var client = new Client(info.host, info.port, false, cert);
		@await client.connect();
		return @await customRequest(client, request, timeout);
	}

	public static function customRequest(client:Client, ?request:HttpRequest, timeout:Float = 10.0, close:Bool = true) {
		request = request ?? {};

		if (!request.headers.exists("Host"))
			request.headers.set("Host", client.remote);

		if (request.data != null && !request.headers.exists("Content-Length"))
			request.headers.set("Content-Length", Std.string(request.data.length));

		return new Lazy((resolve, reject) -> {
			var responsed = false;
			function response(resp:HttpResponse) {
				if (close && !client.isClosed)
					client.close();
				responsed = true;
				resolve(resp);
			}
			client.onData(data -> response(data.toString()));
			client.send(Bytes.ofString(request));
			if (timeout != null && timeout > 0)
				Async.sleep(timeout).handle(_ -> {
					if (!responsed)
						response({
							status: 408,
							statusText: "Request Timeout"
						});
				});
		});
	}

	static function parseURL(url:String) {
		var regex = new EReg("^(https?)://([^:/]+)(:(\\d+))?", "i");
		if (!regex.match(url))
			return null;

		var isSecure = false;
		var host = regex.matched(2);
		var portStr = regex.matched(4);
		var port = {
			if (regex.matched(1).toLowerCase() == "https") {
				isSecure = true;
				443;
			} else
				portStr != null ? Std.parseInt(portStr) : 80;
		}

		return {
			host: host,
			port: port,
			isSecure: isSecure
		}
	}
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
	public var method:String = "GET";
	public var version:String = "HTTP/1.1";
	public var headers:Map<String, String> = [];
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
	public var headers:Map<String, String> = [];
	public var data:String = null;
	public var error:String = null;
	public var cookies:Map<String, String> = [];
}
