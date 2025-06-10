package snet.http;

import haxe.io.Bytes;
import snet.http.Http;

#if !macro
@:build(ssignals.Signals.build())
#end
class HttpServer extends snet.internal.Server<HttpClient> {
	function handleClient(client:HttpClient) {}
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

	public function response(response:HttpResponse) {
		send(Bytes.ofString(response));
	}
}
