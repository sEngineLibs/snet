package snet.http;

import snet.Net;
import snet.http.Http;
import snet.internal.Socket;

@:access(snet.internal.Client)
class Requests {
	public static function request(uri:URI, ?req:HttpRequest, ?proxy:Proxy, timeout:Float = 10.0, ?cert:Certificate) {
		var socket:Socket;
		// if (uri.isSecure)
		// 	socket = new SecureSocket(cert);
		// else
		socket = new Socket();

		if (proxy != null)
			socket.connect(proxy.host);
		else
			socket.connect(uri.host);

		req = req ?? {};
		if (!req.headers.exists(HOST))
			req.headers.set(HOST, uri.host.host);

		if (req.data != null && !req.headers.exists(CONTENT_LENGTH))
			req.headers.set(CONTENT_LENGTH, Std.string(req.data.length));

		return customRequest(socket, true, req, timeout);
	}

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
}
