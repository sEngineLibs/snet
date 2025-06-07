package snet.http;

import haxe.io.Bytes;

using StringTools;

@:forward()
@:forward.new
abstract HttpRequest(HttpRequestData) from HttpRequestData {
	@:from
	public static function fromString(string:String):HttpRequest {
		var lines = string.split("\r\n");
		if (lines.length == 1)
			lines = string.split("\n");

		var method = "GET";
		var headers = new Map<String, String>();

		var requestLine = lines.shift();
		if (requestLine == null || requestLine.trim() == "")
			return {method: method, headers: headers, data: null};

		var parts = requestLine.split(" ");
		if (parts.length >= 1)
			method = parts[0];

		while (lines.length > 0) {
			var line = lines.shift();
			if (line == null || line == "")
				break;

			var sepIndex = line.indexOf(":");
			if (sepIndex > -1) {
				var key = line.substr(0, sepIndex).trim();
				var value = line.substr(sepIndex + 1).trim();
				headers.set(key, value);
			}
		}

		var body = lines.join("\r\n");
		var params:Map<String, String> = null;

		if (headers.exists("Content-Type") && headers.get("Content-Type").indexOf("application/x-www-form-urlencoded") != -1) {
			params = new Map();
			for (pair in body.split("&")) {
				var eq = pair.indexOf("=");
				if (eq > -1) {
					var key = StringTools.urlDecode(pair.substr(0, eq));
					var val = StringTools.urlDecode(pair.substr(eq + 1));
					params.set(key, val);
				}
			}
		}

		return {
			method: method,
			headers: headers,
			data: body,
			params: params
		};
	}

	@:to
	public function toString():String {
		var sb = new StringBuf();

		var m = this.method != null ? this.method : "GET";
		sb.add(m + " / HTTP/1.1\r\n");

		if (this.headers != null)
			for (k in this.headers.keys())
				sb.add(k + ": " + this.headers.get(k) + "\r\n");
		sb.add("\r\n");

		if (this.data != null)
			sb.add(this.data);
		else if (this.params != null) {
			var body = [];
			for (k in this.params.keys())
				body.push(StringTools.urlEncode(k) + "=" + StringTools.urlEncode(this.params.get(k)));
			sb.add(body.join("&"));
		}

		return sb.toString();
	}
}

@:forward()
@:forward.new
abstract HttpResponse(HttpResponseData) from HttpResponseData {
	@:from
	public static function fromString(string:String):HttpResponse {
		var lines = string.split("\r\n");
		if (lines.length == 0)
			return {status: 0, headers: [], error: "Empty response"};

		var statusLine = lines.shift();
		var statusParts = statusLine.split(" ");
		if (statusParts.length < 2)
			return {status: 0, headers: [], error: "Invalid status line"};

		var status = Std.parseInt(statusParts[1]);
		if (status == null)
			return {status: 0, headers: [], error: "Invalid status code"};

		var headers:Map<String, String> = [];
		var line:String;
		while ((line = lines.shift()) != null && line != "") {
			var sepIndex = line.indexOf(":");
			if (sepIndex > -1) {
				var key = line.substr(0, sepIndex).trim();
				var value = line.substr(sepIndex + 1).trim();
				headers.set(key, value);
			}
		}

		var body = lines.join("\r\n");
		return {
			status: status,
			headers: headers,
			data: body
		};
	}

	@:to
	public function toString():String {
		var sb = new StringBuf();
		sb.add("HTTP/1.1 " + this.status + " OK\r\n");

		if (this.headers != null)
			for (k in this.headers.keys())
				sb.add(k + ": " + this.headers.get(k) + "\r\n");
		sb.add("\r\n");

		if (this.data != null)
			sb.add(this.data);

		return sb.toString();
	}
}

private typedef HttpRequestData = {
	method:String,
	?headers:Map<String, String>,
	?data:String,
	?bytes:Bytes,
	?params:Map<String, String>
}

private typedef HttpResponseData = {
	var status:Int;
	var headers:Map<String, String>;
	var ?data:String;
	var ?error:String;
}
