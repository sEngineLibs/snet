package snet.http;

import haxe.io.Bytes;

using StringTools;

@:forward()
abstract Response(ResponseData) from ResponseData {
	@:from
	public static function fromBytes(raw:Bytes):Response {
		var str = raw.toString();
		var headerEnd = str.indexOf("\r\n\r\n");

		if (headerEnd == -1)
			return {
				status: 0,
				statusText: "Error",
				error: "Invalid response: no header terminator"
			};

		var headerPart = str.substr(0, headerEnd);
		var lines = headerPart.split("\r\n");

		var statusLine = lines.shift();
		if (statusLine == null || statusLine.trim() == "")
			return {
				status: 0,
				statusText: "Error",
				error: "Empty status line"
			};

		var parts = statusLine.split(" ");
		var version = parts[0];
		var status = Std.parseInt(parts[1]);
		var statusText = parts.slice(2).join(" ");

		var headers:Map<Header, String> = [];
		var cookies:Map<String, String> = [];

		for (line in lines) {
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

		// body: read binary starting from after \r\n\r\n
		var bodyStart = headerEnd + 4;
		var bodyLength = raw.length - bodyStart;

		// transfer-Encoding: chunked
		if (headers.get(TRANSFER_ENCODING) == "chunked") {
			var bodyStr = raw.sub(bodyStart, bodyLength).toString();
			return {
				version: version,
				status: status,
				statusText: statusText,
				headers: headers,
				cookies: cookies,
				data: parseChunkedBody(bodyStr.split("\r\n"))
			};
		}

		// if Content-Length is set — we know exactly how many bytes to read
		var contentLength = headers.exists(CONTENT_LENGTH) ? Std.parseInt(headers.get(CONTENT_LENGTH)) : bodyLength;

		var contentBytes = raw.sub(bodyStart, contentLength);
		var contentType = headers.get(CONTENT_TYPE);

		// choose whether it's binary or text
		if (contentType != null && contentType.startsWith("text/") || contentType.contains("json")) {
			return {
				version: version,
				status: status,
				statusText: statusText,
				headers: headers,
				cookies: cookies,
				data: contentBytes.toString()
			};
		} else {
			return {
				version: version,
				status: status,
				statusText: statusText,
				headers: headers,
				cookies: cookies,
				bytes: contentBytes
			};
		}
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
	public function toBytes():Bytes {
		var sb = new StringBuf();
		sb.add('${this.version} ${this.status} ${this.statusText}\r\n');

		// cookies
		if (this.cookies != null) {
			for (k in this.cookies.keys())
				sb.add('Set-Cookie: $k=${this.cookies.get(k)}; Path=/\r\n');
		}

		final hasBinary = this.bytes != null;
		final bodyLength = hasBinary ? this.bytes.length : (this.data != null ? Bytes.ofString(this.data).length : 0);

		if (!this.headers.exists(CONTENT_LENGTH))
			this.headers.set(CONTENT_LENGTH, '$bodyLength');

		if (this.data != null && !this.headers.exists(CONTENT_TYPE))
			this.headers.set(CONTENT_TYPE, "text/plain; charset=utf-8");

		// headers
		for (k in this.headers.keys())
			sb.add('$k: ${this.headers.get(k)}\r\n');
		sb.add("\r\n");

		var headBytes = Bytes.ofString(sb.toString());

		var full = Bytes.alloc(headBytes.length + bodyLength);
		full.blit(0, headBytes, 0, headBytes.length);

		if (hasBinary)
			full.blit(headBytes.length, this.bytes, 0, this.bytes.length);
		else if (this.data != null)
			full.blit(headBytes.length, Bytes.ofString(this.data), 0, bodyLength);

		return full;
	}
}

@:structInit
private class ResponseData {
	public var status:Status = OK;
	public var statusText:String = "OK";
	public var version:String = "HTTP/1.1";
	public var headers:Map<Header, String> = [];
	public var data:String = null;
	public var bytes:Bytes = null;
	public var error:String = null;
	public var cookies:Map<String, String> = [];
}
