package snet.http;

#if (nodejs || sys)
import haxe.io.Bytes;
import snet.Net;
import snet.http.Http;
import snet.internal.Socket;
import snet.internal.Client;

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
#end
