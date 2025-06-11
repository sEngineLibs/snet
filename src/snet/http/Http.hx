package snet.http;

import snet.Net;
#if (nodejs || sys)
import haxe.io.Bytes;
import snet.internal.Socket;
#elseif js
import haxe.http.HttpJs;
#end

class Http {
	#if (nodejs || sys)
	public static function request(uri:URI, ?req:HttpRequest, ?proxy:Proxy, timeout:Float = 10.0, ?cert:Certificate)
	#elseif js
	public static function request(uri:URI, ?req:HttpRequest, ?proxy:Proxy, timeout:Float = 10.0)
	#end
	{
		if (uri == null)
			throw new HttpError('Invalid URI: $uri');
		var resp:HttpResponse = {};
		req = req ?? {};
		if (!req.headers.exists(HOST))
			req.headers.set(HOST, uri.host.host);
		#if (nodejs || sys)
		var socket:Socket;
		// if (uri.isSecure)
		// 	socket = new SecureSocket(cert);
		// else
		socket = new Socket();
		if (proxy != null)
			socket.connect(proxy.host);
		else
			socket.connect(uri.host);
		resp = customRequest(socket, true, req, timeout);
		#elseif js
		var http = new HttpJs(uri);

		http.async = false;
		http.onStatus = s -> resp.status = s;
		http.onError = e -> resp.error = e;
		http.onBytes = b -> resp.data = b.toString();
		http.onData = d -> resp.data = d;
		for (h in req.headers.keys())
			http.setHeader(h, req.headers.get(h));
		for (p in req.params.keys())
			http.setParameter(p, req.params.get(p));
		http.setPostData(req.data);
		http.request(req.method == Post);
		resp.headers = http.responseHeaders;
		#end
		return resp;
	}

	#if (nodejs || sys)
	public static function customRequest(socket:Socket, close:Bool, req:HttpRequest, timeout:Float = 10.0) {
		socket.send(req);

		var resp:HttpResponse = try {
			socket.recv(timeout).toString();
		} catch (e)
			null;

		if (close)
			socket.close();

		return resp;
	}
	#end
}

class HttpError extends haxe.Exception {}
typedef HttpStatus = snet.http.Status;
typedef HttpMethod = haxe.http.HttpMethod;
typedef HttpRequest = snet.http.Request;
typedef HttpResponse = snet.http.Response;
