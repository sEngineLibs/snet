package snet.http;

import haxe.io.Bytes;
import snet.http.Http;
import snet.tcp.TCPClient;
import snet.internal.Server;

#if !macro
@:build(ssignals.Signals.build())
#end
class HttpServer extends Server<TCPClient> {
	@:signal function request(request:HttpRequest);

	public function new(host:String, port:Int, limit:Int = 10, secure:Bool = false, open:Bool = true) {
		super(host, port, limit, secure, open);
	}

	public function response(response:HttpResponse) {
		send(Bytes.ofString(response));
	}

	@:slot(clientOpened)
	function trackClient(client:TCPClient) {
		client.onMessage(data -> request(data.toString()));
	}

	@async function handleClient(socket):Bool {
		return true;
	}
}
