package snet.http;

import haxe.io.Bytes;

using StringTools;

@:forward()
abstract Response(ResponseData) from ResponseData {
	@:from
	public static function fromString(raw:String):Response {
		var lines = raw.split("\r\n");
		if (lines.length == 0)
			return {
				status: 0,
				statusText: "Error",
				error: "Empty response"
			};

		var statusLine = lines.shift();
		var parts = statusLine.split(" ");
		var version = parts[0];
		var status = Std.parseInt(parts[1]);
		var statusText = parts.slice(2).join(" ");

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
				if (key.toLowerCase() == "set-cookie") {
					var kv = value.split("=");
					if (kv.length >= 2)
						cookies.set(kv[0], kv[1].split(";")[0]);
				}
			}
		}

		var body = "";
		if (headers.get(TRANSFER_ENCODING) == "chunked")
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
		sb.add('${this.version} ${this.status} ${this.statusText}\r\n');

		// cookies
		if (this.cookies != null) {
			for (k in this.cookies.keys())
				sb.add('Set-Cookie: $k=${this.cookies.get(k)}; Path=/\r\n');
		}

		if (this.data != null) {
			if (!this.headers.exists(CONTENT_LENGTH))
				this.headers.set(CONTENT_LENGTH, Std.string(Bytes.ofString(this.data).length));
			if (!this.headers.exists(CONTENT_TYPE))
				this.headers.set(CONTENT_TYPE, "text/plain; charset=utf-8");
		} else {
			if (!this.headers.exists(CONTENT_LENGTH))
				this.headers.set(CONTENT_LENGTH, "0");
		}

		// headers
		if (this.headers != null)
			for (k in this.headers.keys())
				sb.add('$k: ${this.headers.get(k)}\r\n');

		sb.add("\r\n");

		// body
		if (this.data != null) {
			if (this.headers != null && this.headers.get(TRANSFER_ENCODING) == "chunked") {
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
private class ResponseData {
	public var status:Status = OK;
	public var statusText:String = "OK";
	public var version:String = "HTTP/1.1";
	public var headers:Map<Header, String> = [];
	public var data:String = null;
	public var error:String = null;
	public var cookies:Map<String, String> = [];
}
