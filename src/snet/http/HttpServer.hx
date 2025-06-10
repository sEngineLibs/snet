package snet.http;

import haxe.io.Bytes;
import snet.Net;
import snet.http.Http;
import snet.internal.Socket;

#if !macro
@:build(ssignals.Signals.build())
#end
class HttpServer extends snet.internal.Server<HttpClient> {
	@:signal function request(request:HttpRequest);

	public function new(uri:URI, limit:Int = 10, open:Bool = true, process:Bool = true, ?cert:Certificate) {
		super(uri, limit, open, process, cert);
	}

	public function response(response:HttpResponse) {
		send(Bytes.ofString(response));
	}

	function handleClient(client:HttpClient) {
		client.onRequest(data -> request(data.toString()));
	}
}

#if !macro
@:build(ssignals.Signals.build())
#end
class HttpClient extends snet.internal.Client {
	@:signal function request(request:HttpRequest);

	function connectClient() {}

	function closeClient() {}

	function receive(data:Bytes) {
		request(data.toString());
	}
}
