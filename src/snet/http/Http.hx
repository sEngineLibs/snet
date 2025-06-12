package snet.http;

import sasync.Lazy;
import sasync.Async;
import haxe.io.Bytes;
import snet.Net;
import snet.internal.Client;
#if (nodejs || sys)
import snet.internal.Socket;
#elseif js
import haxe.http.HttpJs;
#end

class HttpError extends haxe.Exception {}
typedef HttpStatus = snet.http.Status;
typedef HttpMethod = haxe.http.HttpMethod;
typedef HttpRequest = snet.http.Request;
typedef HttpResponse = snet.http.Response;

class Http {
	#if (nodejs || sys)
	public static function request(uri:URI, ?req:HttpRequest, ?proxy:Proxy, timeout:Float = 1.0, ?cert:Certificate) @:privateAccess
	#elseif js
	public static function request(uri:URI, ?req:HttpRequest, ?proxy:Proxy, timeout:Float = 1.0)
	#end
	{
		return new Lazy<HttpResponse>((resolve, reject) -> {
			if (uri == null)
				reject(new HttpError('Invalid URI'));
			#if (nodejs || sys)
			req = req ?? {};
			if (!req.headers.exists(HOST))
				req.headers.set(HOST, uri.host.host);
			Async.background(() -> {
				var socket = new Socket();
				if (proxy != null)
					socket.connect(proxy.host.toString());
				else
					socket.connect(uri.host);
				resolve(customRequest(socket, true, req, timeout));
			});
			#elseif js
			var http = new HttpJs(uri);
			var resp:HttpResponse = {};

			function res() {
				resp.headers = http.responseHeaders;
				resolve(resp);
			}

			for (h in req.headers.keys())
				http.setHeader(h, req.headers.get(h));
			for (p in req.params.keys())
				http.setParameter(p, req.params.get(p));
			http.setPostData(req.data);
			http.onStatus = s -> resp.status = s;
			http.onError = e -> reject(e);
			http.onBytes = b -> {
				resp.data = b.toString();
				res();
			}
			http.onData = d -> {
				resp.data = d;
				res();
			}
			http.request(req.data != null || req.method == Post);
			#end
		});
	}
	#if (nodejs || sys)
	public static function customRequest(socket:Socket, close:Bool, req:HttpRequest, timeout:Float = 1.0) {
		socket.output.write(Bytes.ofString(req));
		socket.output.flush();
		var data = socket.read(timeout);
		var resp:HttpResponse = null;
		if (data.length > 0)
			try {
				resp = data.toString();
			} catch (e)
				resp = {
					status: BadGateway,
					statusText: "Server does not support the request method"
				}
		else
			resp = {
				status: GatewayTimeout,
				statusText: "Timed out waiting for response"
			}
		if (close)
			socket.close();
		return resp;
	}
	#end
}
